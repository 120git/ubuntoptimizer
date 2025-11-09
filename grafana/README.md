# Grafana Dashboard for ubopt

This directory contains Grafana dashboards for monitoring Cool Llama ubopt metrics exported via the Prometheus textfile exporter.

## Prerequisites

1. **Prometheus Node Exporter** with textfile collector enabled:
   ```bash
   # Node Exporter should read from /var/lib/node_exporter/textfile_collector/
   node_exporter --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
   ```

2. **ubopt exporter timer** running:
   ```bash
   sudo systemctl enable --now ubopt-exporter.timer
   # Verify metrics file
   cat /var/lib/node_exporter/textfile_collector/ubopt.prom
   ```

3. **Prometheus** configured to scrape Node Exporter:
   ```yaml
   scrape_configs:
     - job_name: 'node'
       static_configs:
         - targets: ['localhost:9100']
   ```

4. **Grafana** with Prometheus datasource configured.

## Importing the Dashboard

### Option 1: Import via UI
1. Open Grafana → Dashboards → Import
2. Upload `dashboards/ubopt-overview.json`
3. Select your Prometheus datasource
4. Click "Import"

### Option 2: Import via API
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_GRAFANA_API_TOKEN" \
  -d @dashboards/ubopt-overview.json \
  http://localhost:3000/api/dashboards/db
```

### Option 3: Provisioning (automated)
1. Copy dashboard to Grafana provisioning directory:
   ```bash
   sudo cp dashboards/ubopt-overview.json /etc/grafana/provisioning/dashboards/
   ```

2. Create provisioning config `/etc/grafana/provisioning/dashboards/ubopt.yaml`:
   ```yaml
   apiVersion: 1
   providers:
     - name: 'ubopt'
       orgId: 1
       folder: 'System Monitoring'
       type: file
       disableDeletion: false
       updateIntervalSeconds: 10
       allowUiUpdates: true
       options:
         path: /etc/grafana/provisioning/dashboards
         foldersFromFilesStructure: true
   ```

3. Restart Grafana:
   ```bash
   sudo systemctl restart grafana-server
   ```

## Dashboard Panels

### 1. Root Filesystem Usage (Gauge)
- **Metric**: `ubopt_root_fs_used_percent`
- **Type**: Gauge with thresholds
- **Thresholds**: 
  - Green: 0-70%
  - Yellow: 70-85%
  - Red: 85-100%

### 2. Last Export Time (Stat)
- **Metric**: `ubopt_last_export_epoch`
- **Type**: Stat panel showing "time from now"
- **Purpose**: Verify exporter is running

### 3. Host Information (Table)
- **Metric**: `ubopt_info`
- **Type**: Table with labels
- **Columns**: Hostname, Kernel, Operating System

## Metrics Reference

The ubopt textfile exporter produces these metrics:

```prometheus
# Static host information
ubopt_info{host="hostname",kernel="6.8.0-86-generic",os="Ubuntu 24.04.3 LTS"} 1

# Root filesystem usage percentage
ubopt_root_fs_used_percent 81

# Last export timestamp (Unix epoch)
ubopt_last_export_epoch 1762652692
```

## Troubleshooting

### Dashboard shows "No Data"
1. Verify exporter is running:
   ```bash
   systemctl status ubopt-exporter.timer
   ls -l /var/lib/node_exporter/textfile_collector/ubopt.prom
   ```

2. Check Prometheus is scraping Node Exporter:
   ```bash
   # Query Prometheus
   curl 'http://localhost:9090/api/v1/query?query=ubopt_info'
   ```

3. Verify datasource in Grafana:
   - Go to Configuration → Data Sources
   - Test your Prometheus connection

### Metrics are stale
- Check timer schedule: `systemctl list-timers ubopt-exporter.timer`
- Manually run: `sudo /usr/lib/ubopt/exporters/ubopt_textfile_exporter.sh`

### Permission denied on textfile directory
```bash
sudo mkdir -p /var/lib/node_exporter/textfile_collector
sudo chown root:root /var/lib/node_exporter/textfile_collector
sudo chmod 755 /var/lib/node_exporter/textfile_collector
```

## Extending the Dashboard

To add custom panels:

1. Add new metrics to `exporters/ubopt_textfile_exporter.sh`
2. Restart the exporter timer
3. Edit the dashboard in Grafana UI
4. Export updated JSON and commit to repo

## Links

- [Prometheus Textfile Collector Documentation](https://github.com/prometheus/node_exporter#textfile-collector)
- [Grafana Dashboard Documentation](https://grafana.com/docs/grafana/latest/dashboards/)
- [ubopt GitHub Repository](https://github.com/120git/ubuntoptimizer)
