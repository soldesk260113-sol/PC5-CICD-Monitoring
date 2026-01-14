const express = require('express');
const app = express();
const port = process.env.PORT || 3000;
const http = require('http'); // Required for making server-side HTTP requests

// Middleware
app.use(express.json());

// Helper function to fetch data from a URL
function fetchData(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (resp) => {
      let data = '';
      resp.on('data', (chunk) => {
        data += chunk;
      });
      resp.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`Failed to parse JSON from ${url}: ${e.message}`));
        }
      });
    }).on('error', (err) => {
      reject(new Error(`Failed to fetch data from ${url}: ${err.message}`));
    });
  });
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Ready check endpoint
app.get('/ready', (req, res) => {
  res.status(200).json({
    status: 'ready',
    timestamp: new Date().toISOString()
  });
});

// API endpoints
app.get('/api/hello', (req, res) => {
  res.json({
    message: 'Hello from Antigravity CI/CD!',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development'
  });
});

app.get('/api/info', (req, res) => {
  res.json({
    app: 'Antigravity Sample App',
    version: process.env.APP_VERSION || '1.0.0',
    node_version: process.version,
    platform: process.platform,
    arch: process.arch
  });
});

// Helper to check service status
function checkService(name, url) {
  return new Promise((resolve) => {
    const start = Date.now();
    const req = http.get(url, (res) => {
      // Consume body
      res.resume();
      const latency = Date.now() - start;
      resolve({ name, url, status: res.statusCode === 200 ? 'Operational' : `Error ${res.statusCode}`, latency, success: res.statusCode === 200 });
    });

    req.on('error', (err) => {
      resolve({ name, url, status: 'Down', error: err.message, success: false });
    });

    req.setTimeout(2000, () => {
      req.destroy();
      resolve({ name, url, status: 'Timeout', success: false });
    });
  });
}

// Root endpoint - Dashboard
app.get('/', async (req, res) => {
  const services = [
    { name: 'Map API', url: 'http://map-api-myapp:80/' },
    { name: 'Energy API', url: 'http://energy-api-myapp:80/health' },
    { name: 'Weather(KMA) API', url: 'http://kma-api-myapp:80/health' }
  ];

  const results = await Promise.all(services.map(s => checkService(s.name, s.url)));

  res.send(`
    <html>
      <head>
        <title>Antigravity Operations Dashboard</title>
        <meta charset="utf-8">
        <style>
          body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f0f2f5; margin: 0; padding: 20px; }
          .container { max-width: 900px; margin: 0 auto; background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
          h1 { color: #1a1a1a; margin-bottom: 5px; }
          p.subtitle { color: #666; margin-bottom: 30px; }
          .status-card { display: flex; align-items: center; justify-content: space-between; padding: 20px; margin-bottom: 15px; border-radius: 8px; border: 1px solid #eee; transition: transform 0.2s; }
          .status-card:hover { transform: translateY(-2px); box-shadow: 0 2px 8px rgba(0,0,0,0.05); }
          .service-info h3 { margin: 0 0 5px 0; font-size: 1.2em; }
          .service-info span { font-family: monospace; color: #888; background: #eee; padding: 2px 6px; border-radius: 4px; font-size: 0.9em; }
          .status-badge { padding: 8px 16px; border-radius: 20px; font-weight: bold; min-width: 100px; text-align: center; }
          .status-operational { background: #e6f7ed; color: #1e7e34; }
          .status-down { background: #ffebee; color: #c62828; }
          .meta { font-size: 0.9em; color: #999; margin-top: 30px; border-top: 1px solid #eee; padding-top: 20px; }
          .refresh-btn { display: inline-block; margin-top: 20px; padding: 10px 20px; background: #007bff; color: white; text-decoration: none; border-radius: 6px; font-weight: bold; }
          .refresh-btn:hover { background: #0056b3; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>🚀 Antigravity Service Dashboard</h1>
          <p class="subtitle">Real-time status of microservice backend mesh</p>
          
          <div class="dashboard">
            ${results.map(r => `
              <div class="status-card" style="border-left: 5px solid ${r.success ? '#28a745' : '#dc3545'}">
                <div class="service-info">
                  <h3>${r.name}</h3>
                  <span>${r.url}</span>
                </div>
                <div style="text-align: right">
                  <div class="status-badge ${r.success ? 'status-operational' : 'status-down'}">
                    ${r.success ? 'OPERATIONAL' : 'DISRUPTION'}
                  </div>
                  <div style="font-size: 0.85em; color: #aaa; margin-top: 5px;">
                    ${r.status} ${r.latency ? `(${r.latency}ms)` : ''}
                  </div>
                </div>
              </div>
            `).join('')}
          </div>

          <a href="/" class="refresh-btn">🔄 Refresh Status</a>

          <div class="meta">
            <p><strong>System Info:</strong></p>
            <ul>
              <li><strong>Environment:</strong> ${process.env.NODE_ENV || 'production'}</li>
              <li><strong>Version:</strong> ${process.env.APP_VERSION || '2.1.0'}</li>
              <li><strong>Pod Host:</strong> ${process.env.HOSTNAME || 'unknown'}</li>
              <li><strong>Last Checked:</strong> ${new Date().toISOString()}</li>
            </ul>
          </div>
        </div>
      </body>
    </html>
  `);
});

// Start server
const server = app.listen(port, () => {
  console.log(`🚀 Antigravity app listening on port ${port}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Version: ${process.env.APP_VERSION || '1.0.0'}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
  });
});
