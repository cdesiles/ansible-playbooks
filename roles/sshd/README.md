# SSH server

## Enable authorized_keys fallback

When you encrypt your home data, you cannot allow hardened remote SSH connection.
To make this still possible, here is the trick: a fallback authorized_key file: /etc/ssh/authorized_keys/myuser

Simply enable this setting to get this working:

```
ssh_authorized_keys_fallback_enabled: true
```

And you're set.
