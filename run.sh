#!/bin/bash

# Fail fast, including pipelines
set -eo pipefail

# Set MOCK_S3_TRACE to enable debugging
[[ "$MOCK_S3_TRACE" ]] && set -x

mkdir -p $SUPERVISORD_LOGS

cat > /etc/supervisor/conf.d/supervisord.conf <<EOF
[supervisord]
nodaemon = true
user = daemon

[unix_http_server]
file=/tmp/supervisor.sock   ; (the path to the socket file)

[eventlistener:stdout] 
command = supervisor_stdout 
buffer_size = 100 
events = PROCESS_LOG 
result_handler = supervisor_stdout:event_handler
EOF

cat > /tmp/mock_s3.sh <<EOF
#!/bin/bash
source $MOCK_S3_ROOT/.profile
[[ "$MOCK_S3_TRACE" ]] && set -x
exec mock_s3 --host 0.0.0.0 --port $MOCK_S3_PORT --root $MOCK_S3_ROOT
EOF

cat > /etc/supervisor/conf.d/mock_s3.conf <<EOF
[program:mock_s3]
command=/bin/bash /tmp/mock_s3.sh
priority=10
directory=/tmp
process_name=%(program_name)s
autostart=true
autorestart=true
stdout_events_enabled=true
stderr_events_enabled=true
stopsignal=TERM
stopwaitsecs=1
EOF

AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-dummy}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-dummy}
AWS_ENDPOINT=${AWS_ENDPOINT:-127.0.0.1}
AWS_S3_PORT=${AWS_S3_PORT:-$MOCK_S3_PORT}
AWS_S3_SCHEME=${AWS_S3_SCHEME:-http}

env | xargs -l1 echo export > $MOCK_S3_ROOT/.profile

[[ "$MOCK_S3_TRACE" ]] && env

cat <<EOF > $MOCK_S3_ROOT/.s3cfg
[default]
access_key = ${AWS_ACCESS_KEY_ID}
bucket_location = US
cloudfront_host = cloudfront.amazonaws.com
cloudfront_resource = /2010-07-15/distribution
default_mime_type = binary/octet-stream
delete_removed = False
dry_run = False
enable_multipart = False
encoding = UTF-8
encrypt = False
follow_symlinks = False
force = False
get_continue = False
gpg_command = /usr/local/bin/gpg
gpg_decrypt = %(gpg_command)s -d --verbose --no-use-agent --batch --yes --passphrase-fd %(passphrase_fd)s -o %(output_file)s %(input_file)s
gpg_encrypt = %(gpg_command)s -c --verbose --no-use-agent --batch --yes --passphrase-fd %(passphrase_fd)s -o %(output_file)s %(input_file)s
gpg_passphrase = password
guess_mime_type = True
host_base = s3.amazonaws.com
host_bucket = %(bucket)s.s3.amazonaws.com
human_readable_sizes = False
list_md5 = False
log_target_prefix =
preserve_attrs = True
progress_meter = True
proxy_host = ${AWS_ENDPOINT}
proxy_port = 8080
recursive = False
recv_chunk = 4096
reduced_redundancy = False
secret_key = ${AWS_SECRET_ACCESS_KEY}
send_chunk = 4096
simpledb_host = sdb.amazonaws.com
skip_existing = False
socket_timeout = 300
urlencoding_mode = normal
use_https = False
verbosity = WARNING
EOF

cat > /tmp/make_buckets.sh <<EOF
#!/bin/bash
sleep 1
source $MOCK_S3_ROOT/.profile
[[ "$MOCK_S3_TRACE" ]] && set -x
if [[ "$MAKE_BUCKETS" ]] ; then
 IFS=, BUCKETS=( \$MAKE_BUCKETS )
 IFS=' '
 for MAKE_BUCKET in \${BUCKETS[*]} ; do
   while ! s3cmd -c $MOCK_S3_ROOT/.s3cfg mb s3://\${MAKE_BUCKET} ; do
     echo "Failed to create bucket '\$MAKE_BUCKET'. Retrying..."
     sleep 1
   done
 done
fi
EOF

cat > /etc/supervisor/conf.d/make_buckets.conf <<EOF
[program:make_buckets]
command=/bin/bash /tmp/make_buckets.sh
priority=10
directory=/tmp
process_name=%(program_name)s
autostart=true
autorestart=false
startsecs=1
exitcodes=0
stopwaitsecs=1
stopsignal=TERM
stdout_events_enabled=true
stderr_events_enabled=true
EOF

# start supervisord
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
