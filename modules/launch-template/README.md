# Module: launch-template

Reusable EC2 launch template for Spoke application instances. Bootstrap logic
(`user_data`) defaults to the reference architecture's minimal Apache/httpd
setup but is fully configurable - this module doesn't hard-code an
application-specific bootstrap beyond that default.

AMI selection is dynamic by default (`data.aws_ami` looks up the latest
Amazon Linux 2023 AMI) so the module never encodes an AMI ID that will
silently go stale.
