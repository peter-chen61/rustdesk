# Privacy and deployment behavior

This customization is for support sessions authorized by the organization and device user or owner. It is not intended to conceal remote access or to enable access without authorization.

The application uses the administrator-selected self-hosted ID/relay server to register and establish connections. Remote-support features can transfer screen contents, input, clipboard data, audio or files according to the settings and permissions used. Hiding the server-settings entry does not make this traffic or the local configuration secret.

The generic deployment script reads a local server profile and an administrator-supplied permanent access password. It does not send these deployment inputs to SignPath. The password is passed to RustDesk's local password-setting command; administrators of the device may be able to observe process arguments. A password file, when used for managed deployment, must be protected separately and not committed or distributed publicly.

On a failure, the script may create a local report containing service account/profile paths, relevant public server configuration, query output and error locations. It redacts the supplied password from its failure text and does not intentionally dump complete configuration files. Reports are not uploaded automatically. Review any report before sharing it.

The upstream application has its own network, update and service behavior. See [upstream documentation](https://rustdesk.com/docs/) and review dependency behavior before adopting the project. This policy does not claim that all upstream traffic has been independently audited.
