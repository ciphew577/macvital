# MacVital — Complete Metrics Reference
## Sourced from: Stats (37k★), MacVitals, rambar, Monit, Apple Activity Monitor

---

## CPU Module
### Dashboard
- Total usage % (pie chart)
- Temperature gauge (half-circle)
- Frequency gauge (half-circle)

### Details
- System %
- User %
- Idle %
- Efficiency cores % (Apple Silicon)
- Performance cores % (Apple Silicon)
- Super cores % (Apple Silicon, M5+)
- Scheduler limit % (Intel)
- Speed limit % (Intel)
- Uptime

### Charts
- Usage history (line chart, 180s)
- Per-core usage (column chart, color by core type)

### Load Average
- 1 minute
- 5 minutes
- 15 minutes

### Frequency
- All cores (MHz)
- Efficiency cores (MHz)
- Performance cores (MHz)

### Top Processes
- Process name + CPU % (top N)

---

## Memory (RAM) Module
### Dashboard
- Memory usage % (pie chart: app/wired/compressed/free)
- Memory pressure gauge (needle: 1=Normal, 2=Warning, 3=Critical)

### Details
- Used (total)
- App Memory (color)
- Wired Memory (color)
- Compressed (color)
- Free (color)
- Swap Used

### Chart
- Usage history (line)

### Top Processes
- Process name + memory usage

### From MacVitals (extra)
- Sunburst pie chart by app
- Per-app process tree with individual process memory
- Swap donut ring
- Disk Free (swap context)
- AI recommendation ("this workload aligns better with X GB RAM")

### From rambar (extra)
- Per-app aggregated RSS from ps aux
- Chrome tab-level memory breakdown
- Color-coded app grouping

### From Activity Monitor
- App Memory
- Wired Memory
- Compressed
- Cached Files
- Swap Used
- Physical Memory
- Memory Used
- Memory Pressure graph

---

## Disk Module
### Per Volume
- Name + mount path
- Free space / Total capacity
- Used space / Total capacity
- Usage % (bar)

### I/O Stats
- Read speed (current)
- Write speed (current)
- Total read (cumulative)
- Total written (cumulative)
- Read/Write activity dots

### SMART Data
- Temperature (°C)
- Health %
- Power cycles
- Power on hours
- Total read (SMART)
- Total written (SMART)

### Chart
- Read/Write activity history (line, 120pt)

---

## Battery Module
### Dashboard
- Level % (gauge + mAh)

### Details
- Level (% + current capacity tooltip)
- Source (Battery/AC)
- Time to discharge / Time to charge
- Last charge (time since AC)

### Battery Section
- Health % (+ state)
- Capacity: Current / Maximum / Designed (mAh)
- Cycles
- Temperature
- Power (watts, from V × A)
- Current (mA)
- Voltage (V)

### Power Adapter Section
- Is charging (yes/no)
- Power (AC watts)
- Current (charging mA)
- Voltage (charging mV)

### Top Processes
- Process name + energy usage %

---

## Network Module
### Dashboard
- Download speed (current)
- Upload speed (current)

### Details
- Total upload (cumulative)
- Total download (cumulative)
- Status (UP/DOWN)
- Internet connection (UP/DOWN)
- Latency (ms)
- Jitter (ms)

### Interface Section
- Interface name + BSD identifier
- Status
- Physical address (MAC)
- Network (WiFi SSID + signal strength)
- Standard (WiFi protocol)
- Channel
- Speed (link rate)
- DNS Server(s)

### Address Section
- Local IP (IPv4/IPv6)
- Public IP (IPv4 + country flag)
- Public IP (IPv6 + country flag)

### Charts
- Usage history (traffic over time)
- Connectivity history (timeline)

### Top Processes
- Per-app download/upload speed

---

## GPU Module
### Dashboard
- GPU temperature (half-circle gauge)
- GPU utilization % (half-circle gauge)
- Render utilization % (half-circle gauge)
- Tiler utilization % (half-circle gauge)

### Details
- Vendor
- Model
- Cores
- Status (Active/Non-active)
- Fan speed %
- Core clock (MHz)
- Memory clock (MHz)
- Temperature
- Utilization %
- Render utilization %
- Tiler utilization %

### Chart
- Utilization history (line, 120pt)

---

## Sensors Module
### Categories
- **Temperature**: CPU die, CPU proximity, GPU, SSD, Battery, Ambient, Skin, NAND, Thunderbolt, each as individual sensor reading
- **Voltage**: CPU core, GPU, Memory, Battery, System
- **Power**: CPU package, GPU, DRAM, System total, each in Watts
- **Current**: Battery charge/discharge in mA
- **Fan Speed**: Per-fan RPM, min RPM, max RPM

### Per Sensor
- Name
- SMC Key
- Current value
- Unit (°C, V, W, A, RPM)
- Historical chart

---

## Monit-Style Menu Bar Popover
- 4 circular gauges: CPU%, Memory%, Disk%, Battery%
- Network: ↓ speed, ↑ speed
- Public IP, Local IP, WiFi SSID
- Upload/Download totals + peaks

---

## Key Design Patterns
1. **Gauge + Details + Chart + Top Processes** per module
2. Every module has: dashboard visualization, key metrics list, history chart, process list
3. Color coding: green (good) / orange (warning) / red (critical)
4. Monospaced digits for all numbers
5. Each metric shows both value and unit
6. Expandable/collapsible sections
7. Per-core breakdown in CPU
8. Per-volume breakdown in Disk
9. Per-interface breakdown in Network
10. Per-app breakdown in Memory (MacVitals/rambar style)
