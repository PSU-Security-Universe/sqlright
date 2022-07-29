import psutil
import time
from datetime import datetime

# Global configurations

monitor_CPU_logic_cores = list(range(8))
log_file = "./cpu_usage.txt"

log_file = open(log_file, 'w+')
log_file.write("datetime,cpu_percent,cpu_core\n")

start_time = time.time()

while (True):
    # Log CPU usage
    cpu_usage_l = psutil.cpu_percent(3.0, percpu=True)
    for i in monitor_CPU_logic_cores:
        cpu_usage = cpu_usage_l[i]
        log_file.write("%s,%d,%d\n" % (datetime.now().strftime("%m/%d/%Y:%H:%M:%S"), cpu_usage, i))
        log_file.flush()
    time.sleep(60.0 - ((time.time() - start_time) % 60.0))
