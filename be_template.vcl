
backend %BE_NAME% {
    .host = "%BE_IP%";
    .port = "%BE_PORT%";
    .probe = {
        .url = "%BE_PATH%";
        .timeout = %PROBE_TIMEOUT%;
        .interval = %PROBE_INTERVAL%;
        .window = %PROBE_WINDOW%;
        .threshold = %PROBE_THRESHOLD%;
    }
}
