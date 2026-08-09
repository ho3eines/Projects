using System.Dynamic;
using System.Globalization;
using System.Reflection;
using System.Text;

namespace BlazorDeployService.Services
{
    #region ===================== ATTRIBUTES =====================

    [AttributeUsage(AttributeTargets.Class)]
    public sealed class TableAttribute : Attribute
    {
        public string Name { get; }
        public int TableVersion { get; set; } = 0;

        public TableAttribute(string name) : this(name, 0) { }

        public TableAttribute(string name, int tableVersion) 
        {
            Name = name;
            TableVersion = tableVersion;
        }
    }

    [AttributeUsage(AttributeTargets.Property)]
    public sealed class PrimaryKeyAttribute : Attribute { }

    [AttributeUsage(AttributeTargets.Property)]
    public sealed class IdentityAttribute : Attribute { }

    [AttributeUsage(AttributeTargets.Property)]
    public sealed class RequiredAttribute : Attribute { }

    [AttributeUsage(AttributeTargets.Property)]
    public sealed class MaxLengthAttribute : Attribute
    {
        public int Length { get; }
        public MaxLengthAttribute(int length) => Length = length;
    }

    [AttributeUsage(AttributeTargets.Property)]
    public sealed class SqlTypeAttribute : Attribute
    {
        public string SqlType { get; }
        public SqlTypeAttribute(string sqlType) => SqlType = sqlType;
    }

    [AttributeUsage(AttributeTargets.Property)]
    public sealed class DefaultAttribute : Attribute
    {
        public string Expression { get; }
        public DefaultAttribute(string expression) => Expression = expression;
    }

    #endregion

    #region ===================== RESULT MODELS =====================

    public sealed class SqlParameterInfo
    {
        public string Name { get; set; } = default!;
        public string SqlType { get; set; } = default!;
    }

    public sealed class SqlScriptResult
    {
        public string CommandText { get; set; } = string.Empty;
        public List<SqlParameterInfo> Parameters { get; set; } = new();
    }

    #endregion

    #region ===================== INTERFACE =====================

    /// <summary>
    /// سرویسهای ارتباط با بانک اطلاعاتی
    /// </summary>
    public interface ISqlService
    {
        /// <summary>
        /// مدل را به این تابع بدید بررسی میکنه در دیتابیس وجود دارد یا در صورت نبودن ایجاد میکند
        /// </summary>
        Task InitializeAsync<T>() where T : class;

        /// <summary>
        /// برای اینسرت در جدول پایگاه داده، مدل حتما باید طبق الگو خاص باشد
        /// </summary>
        Task Insert<T>(object values) where T : class;

        /// <summary>
        /// برای update در جدول پایگاه داده، مدل حتما باید طبق الگو خاص باشد
        /// </summary>
        Task Update<T>(object values, object where) where T : class;

        /// <summary>
        /// برای فراخوانی از جدول پایگاه داده، مدل حتما باید طبق الگو خاص باشد
        /// </summary>
        Task<List<T>> Select<T>() where T : class;

        /// <summary>
        /// برای فراخوانی از جدول پایگاه داده، مدل حتما باید طبق الگو خاص باشد
        /// </summary>
        Task<List<T>> Select<T>(object where) where T : class;

        /// <summary>
        /// برای delete در جدول پایگاه داده، مدل حتما باید طبق الگو خاص باشد
        /// </summary>
        Task Delete<T>(object where) where T : class;

        /// <summary>
        /// برای تبدیل UnixTime به تاریخ میلادی از این تابع استفاده کنید
        /// </summary>
        DateTime UnixTimeToDateTime(long unixTime);

        /// <summary>
        /// برای تبدیل تاریخ به UnixTime از این تابع استفاده کنید
        /// </summary>
        long DateTimeToUnixTime(DateTime dateTime);

        /// <summary>
        /// برای تبدیل UnixTime به تاریخ شمسی از این تابع استفاده کنید
        /// </summary>
        string UnixTimeToPersian(long unixTime);
    }

    #endregion

    #region ===================== IMPLEMENTATION =====================

    public sealed class SqlService : ISqlService
    {
        #region ---------- INITIALIZE ----------
        private readonly IRequestService _req;
        private readonly IClientStorageService _local;
        public SqlService(IRequestService req, IClientStorageService local)
        {
            _req = req;
            _local = local;
        }
        public async Task InitializeAsync<T>() where T : class
        {
            var table = GetTableName(typeof(T));
            var columns = GetColumns(typeof(T));
            var version = GetTableVersion(typeof(T));

            var sb = new StringBuilder();

            if (await _local.GetLocalAsync<int>($"Table_{table}") < version)
            {
                sb.AppendLine($@"
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = '{table}')
BEGIN
    CREATE TABLE [{table}] (
{string.Join(", ", columns.Select(c => " " + c.Definition))}
    );
END
ELSE
BEGIN");

                foreach (var col in columns)
                {
                    sb.AppendLine($@"
    IF NOT EXISTS (
        SELECT 1 FROM sys.columns 
        WHERE Name = '{col.Name}'
          AND Object_ID = Object_ID('{table}')
    )
    BEGIN
        ALTER TABLE [{table}] ADD {col.Definition};
    END");
                }

                sb.AppendLine("END");
                if (!string.IsNullOrEmpty(sb.ToString()))
                    await _req.Request<T>(sb.ToString().Replace("{", "").Replace("}", ""), null, true);

                await _local.SetLocalAsync($"Table_{table}", version);
            }
        }

        #endregion

        #region ---------- INSERT ----------

        public async Task Insert<T>(object values) where T : class
        {
            var table = GetTableName(typeof(T));

            var props = values.GetType()
                .GetProperties()
                .Where(p => HasValue(p.GetValue(values)))
                .ToList();

            if (!props.Any())
                throw new InvalidOperationException("No valid values to insert.");

            var sql = new SqlScriptResult
            {
                CommandText =
$@"INSERT INTO [{table}] ({string.Join(",", props.Select(p => p.Name))})
VALUES ({string.Join(",", props.Select(p => "@" + p.Name))});",

                Parameters = BuildParameters(typeof(T), props)
            };


            await _req.Request<T>(sql.CommandText, values, true);
        }

        #endregion

        #region ---------- UPDATE ----------

        public async Task Update<T>(object values, object where) where T : class
        {
            var table = GetTableName(typeof(T));

            var valueProps = values.GetType()
                .GetProperties()
                .Where(p => HasValue(p.GetValue(values)))
                .ToList();

            if (!valueProps.Any())
                throw new InvalidOperationException("No values to update.");

            var whereProps = where.GetType().GetProperties();

            var sql = new SqlScriptResult
            {
                CommandText =
$@"UPDATE [{table}]
SET {string.Join(", ", valueProps.Select(p => $"{p.Name} = @v_{p.Name}"))}
WHERE {string.Join(" AND ", whereProps.Select(p => $"{p.Name} = @w_{p.Name}"))};",

                Parameters = BuildParameters(typeof(T), valueProps.Concat(whereProps))
            };

            var paramDict = new Dictionary<string, object>();

            foreach (var prop in valueProps)
            {
                paramDict[$"v_{prop.Name}"] = prop.GetValue(values) ?? DBNull.Value;
            }

            foreach (var prop in whereProps)
            {
                paramDict[$"w_{prop.Name}"] = prop.GetValue(where) ?? DBNull.Value;
            }

            // تبدیل به آبجکت ناشناس برای Dapper
            var anonymousParams = CreateAnonymousObject(paramDict);

            await _req.Request<T>(sql.CommandText, anonymousParams, true);
        }

        #endregion

        #region ---------- SELECT ----------

        public async Task<List<T>> Select<T>() where T : class
        {
            var sql = new
            {
                CommandText = $"SELECT * FROM [{GetTableName(typeof(T))}];"
            };

            //Console.WriteLine($"\n sql={sql.CommandText}");

            List<T> resp = await _req.GetData<T>(sql.CommandText);

            //Console.WriteLine($"\n response = {JsonConvert.SerializeObject(resp)}");

            return resp;
        }

        public async Task<List<T>> Select<T>(object where) where T : class
        {
            var table = GetTableName(typeof(T));
            var props = where.GetType().GetProperties();

            var sql = new
            {
                CommandText =
$@"SELECT * FROM [{table}]
WHERE {string.Join(" AND ", props.Select(p => $"{p.Name}=@{p.Name}"))};",

                Parameters = BuildParameters(typeof(T), props)
            };

            return await _req.GetData<T>(sql.CommandText, where);
        }

        #endregion

        #region ---------- DELETE ----------

        public async Task Delete<T>(object where) where T : class
        {
            var table = GetTableName(typeof(T));
            var props = where.GetType().GetProperties();

            var sql = new SqlScriptResult
            {
                CommandText =
$@"DELETE FROM [{table}]
WHERE {string.Join(" AND ", props.Select(p => $"{p.Name}=@{p.Name}"))};",

                Parameters = BuildParameters(typeof(T), props)
            };

            await _req.Request<T>(sql.CommandText, where, true);
        }

        #endregion

        #region ===================== HELPERS =====================

        private static bool HasValue(object? value)
        {
            if (value == null) return false;
            if (value is string s) return !string.IsNullOrWhiteSpace(s);
            return true;
        }

        private static string GetTableName(Type type)
        {
            return type.GetCustomAttribute<TableAttribute>()?.Name
                   ?? throw new InvalidOperationException("Missing [Table] attribute");
        }

        private static int GetTableVersion(Type type)
        {
            return type.GetCustomAttribute<TableAttribute>()?.TableVersion
                   ?? throw new InvalidOperationException("Missing [Table] attribute");
        }

        private static IEnumerable<(string Name, string Definition)> GetColumns(Type type)
        {
            foreach (var prop in type.GetProperties())
            {
                var sqlType = ResolveSqlType(prop);
                var required = prop.GetCustomAttribute<RequiredAttribute>() != null ? "NOT NULL" : "NULL";
                var identity = prop.GetCustomAttribute<IdentityAttribute>() != null ? "IDENTITY(1,1)" : "";
                var pk = prop.GetCustomAttribute<PrimaryKeyAttribute>() != null ? "PRIMARY KEY" : "";
                var def = prop.GetCustomAttribute<DefaultAttribute>()?.Expression;

                var parts = new List<string>
                {
                    $"[{prop.Name}]",
                    sqlType,
                    identity,
                    required,
                    pk
                };

                if (!string.IsNullOrWhiteSpace(def))
                    parts.Add($"DEFAULT {def}");

                yield return (prop.Name, string.Join(" ", parts.Where(p => p != "")));
            }
        }

        private static List<SqlParameterInfo> BuildParameters(Type model, IEnumerable<PropertyInfo> props)
        {
            var modelProps = model.GetProperties()
                .ToDictionary(p => p.Name, StringComparer.OrdinalIgnoreCase);

            return props.Select(p => new SqlParameterInfo
            {
                Name = "@" + p.Name,
                SqlType = ResolveSqlType(modelProps[p.Name])
            }).ToList();
        }
        private object CreateAnonymousObject(Dictionary<string, object> dict)
        {
            var expando = new ExpandoObject();
            var expandoDict = expando as IDictionary<string, object>;

            foreach (var kvp in dict)
            {
                expandoDict[kvp.Key] = kvp.Value;
            }

            return expando;
        }

        private static string ResolveSqlType(PropertyInfo prop)
        {
            var sql = prop.GetCustomAttribute<SqlTypeAttribute>()?.SqlType;
            if (sql != null) return sql;

            if (prop.PropertyType == typeof(string))
            {
                var max = prop.GetCustomAttribute<MaxLengthAttribute>();
                return max != null ? $"NVARCHAR({max.Length})" : "NVARCHAR(MAX)";
            }

            if (prop.PropertyType == typeof(int)) return "INT";
            if (prop.PropertyType == typeof(long)) return "BIGINT";
            if (prop.PropertyType == typeof(bool)) return "BIT";
            if (prop.PropertyType == typeof(DateTime)) return "DATETIME2";
            if (prop.PropertyType == typeof(decimal)) return "DECIMAL(18,2)";

            throw new NotSupportedException($"Unsupported type {prop.PropertyType.Name}");
        }


        public DateTime UnixTimeToDateTime(long unixTime)
        {
            return DateTimeOffset.FromUnixTimeSeconds(unixTime).UtcDateTime;
        }


        public long DateTimeToUnixTime(DateTime dateTime)
        {
            return new DateTimeOffset(dateTime).ToUnixTimeSeconds();
        }


        public string UnixTimeToPersian(long unixTime)
        {
            unixTime += 12600;  // به خاطر تایم زون ایران

            DateTime dateTime = UnixTimeToDateTime(unixTime);

            var persianCalendar = new PersianCalendar();

            int year = persianCalendar.GetYear(dateTime);
            int month = persianCalendar.GetMonth(dateTime);
            int day = persianCalendar.GetDayOfMonth(dateTime);

            return $"{year:0000}/{month:00}/{day:00}";
        }

        #endregion
    }

    #endregion
}
