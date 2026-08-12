namespace Tarazin.Data;

/// <summary>
/// Abstraction over the current signed-in user, so the **Data layer never
/// depends on the UI layer**. The UI host registers the concrete
/// implementation (Tarazin.Ui/Services/UserSession implements it).
///
/// DbService uses it to stamp audit rows with the acting user; when no one
/// is signed in (e.g. startup seeding) it is an empty string.
/// </summary>
public interface ICurrentUser
{
    string UserName { get; }
}
