#!/bin/bash
# hermes-dev-skill/tests/fixtures/fake_hermes.sh
# A fake `hermes` CLI used in unit tests. Records args, returns a fake
# message_id, and supports configurable failure modes.
echo "$0 $@" >> "${HERMES_TEST_LOG:-/tmp/hermes_test.log}"
case "${HERMES_TEST_FAIL:-ok}" in
    ok)
        echo "message_id: om_test_${RANDOM}"
        exit 0
        ;;
    fail)
        echo "hermes send failed" >&2
        exit 1
        ;;
esac
