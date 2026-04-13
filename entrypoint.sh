#!/bin/bash
set -e

TIMEOUT="${INPUT_TIMEOUT_MINUTES:-30}"
SERVER_HOST="${INPUT_SERVER_HOST:-tmtv.se}"
SERVER_PORT="${INPUT_SERVER_PORT:-22}"
SERVER_RSA_FINGERPRINT="${INPUT_SERVER_RSA_FINGERPRINT:-}"
SERVER_ED25519_FINGERPRINT="${INPUT_SERVER_ED25519_FINGERPRINT:-}"
INSTALL_URL="${INPUT_INSTALL_URL:-https://tmtv.se/install.sh}"
LIMIT_ACCESS="${INPUT_LIMIT_ACCESS_TO_ACTOR:-false}"

echo "::group::Installing tmtv"
curl -fsSL "$INSTALL_URL" | sh
echo "::endgroup::"

# Verify installation
if ! command -v tmtv >/dev/null 2>&1; then
    echo "::error::tmtv installation failed"
    exit 1
fi

echo "::group::tmtv version"
tmtv -V
echo "::endgroup::"

# Create tmtv config
TMTV_CONF="$HOME/.tmtv.conf"
cat > "$TMTV_CONF" << EOF
set -g tmtv-server-host "$SERVER_HOST"
set -g tmtv-server-port $SERVER_PORT
set -g tmtv-server-rsa-fingerprint $SERVER_RSA_FINGERPRINT
set -g tmtv-server-ed25519-fingerprint $SERVER_ED25519_FINGERPRINT
EOF

# If limit-access-to-actor is set, fetch the actor's SSH keys from GitHub
# and configure authorized_keys so only they can connect
if [ "$LIMIT_ACCESS" = "true" ] && [ -n "$GITHUB_ACTOR" ]; then
    echo "::group::Fetching SSH keys for $GITHUB_ACTOR"
    KEYS=$(curl -fsSL "https://github.com/$GITHUB_ACTOR.keys" 2>/dev/null || true)
    if [ -n "$KEYS" ]; then
        mkdir -p "$HOME/.ssh"
        echo "$KEYS" > "$HOME/.ssh/authorized_keys"
        chmod 600 "$HOME/.ssh/authorized_keys"
        echo "Authorized $(echo "$KEYS" | wc -l) SSH key(s) for $GITHUB_ACTOR"
    else
        echo "::warning::Could not fetch SSH keys for $GITHUB_ACTOR — session will be open to anyone with the token"
    fi
    echo "::endgroup::"
fi

# Start tmtv session in background
tmtv -f "$TMTV_CONF" new-session -d -s ci-debug

# Wait for the session to register and get tokens
sleep 5

# Extract session info from tmtv
echo ""
echo "========================================"
echo "  tmtv debug session is ready!"
echo "========================================"
echo ""
echo "  Connect via SSH:"
echo "    ssh <TOKEN>@${SERVER_HOST}"
echo ""
echo "  Check tmtv output above for your tokens."
echo "  Read-write token: full shell access"
echo "  Read-only token:  watch only"
echo ""
if [ "$LIMIT_ACCESS" = "true" ] && [ -n "$KEYS" ]; then
    echo "  Access limited to: $GITHUB_ACTOR"
fi
echo ""
echo "  Session will timeout in ${TIMEOUT} minutes."
echo "  To end early: detach from tmtv (prefix + d)"
echo "  or touch /tmp/tmtv-continue"
echo ""
echo "========================================"
echo ""

# Wait for timeout or user signal to continue
SECONDS=0
TIMEOUT_SECS=$((TIMEOUT * 60))

while [ $SECONDS -lt $TIMEOUT_SECS ]; do
    # Check if user wants to continue the pipeline
    if [ -f /tmp/tmtv-continue ]; then
        echo "Found /tmp/tmtv-continue — resuming pipeline."
        break
    fi

    # Check if tmtv session is still alive
    if ! tmtv list-sessions >/dev/null 2>&1; then
        echo "tmtv session ended — resuming pipeline."
        break
    fi

    sleep 5
done

if [ $SECONDS -ge $TIMEOUT_SECS ]; then
    echo "Timeout reached (${TIMEOUT} minutes) — resuming pipeline."
fi

# Cleanup
tmtv kill-server 2>/dev/null || true
rm -f "$TMTV_CONF"
