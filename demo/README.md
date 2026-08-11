# Runnable database demo

The demo executes a complete synthetic workflow inside one transaction:

1. creates a patient and doctor;
2. calls `book_appointment()` without copying UUIDs;
3. shows the generated appointment and `PENDING` payment;
4. calls `process_payment(..., 'SUCCESS')`;
5. calls `complete_appointment()`;
6. shows appointment audit rows;
7. queries doctor utilization, daily revenue, and patient statistics;
8. asserts the expected state and rolls everything back.

No real patient data is used and a successful run leaves no demo rows behind.

PowerShell:

```powershell
./demo/run_demo.ps1
```

Bash, WSL, or Git Bash:

```bash
bash ./demo/run_demo.sh
```

The runners require healthy Compose services and validate Flyway before
executing `demo.sql` with `ON_ERROR_STOP=1`.
