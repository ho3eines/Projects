FROM mcr.microsoft.com/mssql/server:2022-latest

# Railway volumes are mounted with permissions that may not be writable by the
# non-root mssql user. Running the database process as root avoids the /.system
# startup failure. Keep this workaround limited to the SQL Server service.
USER root

EXPOSE 1433
