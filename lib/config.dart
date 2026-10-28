/// The admin (user 2) can edit or delete any expense and undo payments.
/// Keep this in sync with `isAdmin()` in firestore.rules.
const adminEmail = 'mahathirbishal@gmail.com';

bool isAdminEmail(String? email) =>
    email != null && email.toLowerCase() == adminEmail;
