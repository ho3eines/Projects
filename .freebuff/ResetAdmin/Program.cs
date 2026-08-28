using System;
using System.Security.Cryptography;
var salt = RandomNumberGenerator.GetBytes(16);
var key = Rfc2898DeriveBytes.Pbkdf2("admin", salt, 100000, HashAlgorithmName.SHA256, 32);
Console.Write($"100000.{Convert.ToBase64String(salt)}.{Convert.ToBase64String(key)}");
