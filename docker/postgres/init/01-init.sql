-- NeonLink PostgreSQL Database Initialization
-- Creates tables and initial data

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Telemetry Data Table
CREATE TABLE IF NOT EXISTS telemetry_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    sensor_name VARCHAR(100) NOT NULL,
    sensor_value DECIMAL(10, 2) NOT NULL,
    sensor_unit VARCHAR(20),
    category VARCHAR(50),
    device_id VARCHAR(100),
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for telemetry data
CREATE INDEX IF NOT EXISTS idx_telemetry_timestamp ON telemetry_data(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_sensor_name ON telemetry_data(sensor_name);
CREATE INDEX IF NOT EXISTS idx_telemetry_category ON telemetry_data(category);
CREATE INDEX IF NOT EXISTS idx_telemetry_device_id ON telemetry_data(device_id);

-- Settings Table
CREATE TABLE IF NOT EXISTS settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key VARCHAR(100) UNIQUE NOT NULL,
    value TEXT NOT NULL,
    value_type VARCHAR(20) DEFAULT 'string',
    description TEXT,
    category VARCHAR(50),
    is_encrypted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Scripts Table
CREATE TABLE IF NOT EXISTS scripts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    content TEXT NOT NULL,
    language VARCHAR(20) DEFAULT 'powershell',
    version VARCHAR(20) DEFAULT '1.0',
    author VARCHAR(100),
    is_enabled BOOLEAN DEFAULT TRUE,
    execution_count INTEGER DEFAULT 0,
    last_executed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Script Execution Logs
CREATE TABLE IF NOT EXISTS script_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    script_id UUID REFERENCES scripts(id) ON DELETE CASCADE,
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    finished_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) NOT NULL,
    output TEXT,
    error_output TEXT,
    exit_code INTEGER,
    execution_time_ms INTEGER,
    executed_by VARCHAR(100)
);

-- Indexes for script logs
CREATE INDEX IF NOT EXISTS idx_script_logs_script_id ON script_logs(script_id);
CREATE INDEX IF NOT EXISTS idx_script_logs_started_at ON script_logs(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_script_logs_status ON script_logs(status);

-- Connections Table
CREATE TABLE IF NOT EXISTS connections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(200) NOT NULL,
    host VARCHAR(255) NOT NULL,
    port INTEGER DEFAULT 9876,
    protocol VARCHAR(20) DEFAULT 'websocket',
    is_ssl BOOLEAN DEFAULT FALSE,
    username VARCHAR(100),
    last_connected_at TIMESTAMP WITH TIME ZONE,
    is_favorite BOOLEAN DEFAULT FALSE,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Health Check Log
CREATE TABLE IF NOT EXISTS health_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_name VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL,
    response_time_ms INTEGER,
    error_message TEXT,
    checked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for health logs
CREATE INDEX IF NOT EXISTS idx_health_logs_checked_at ON health_logs(checked_at DESC);
CREATE INDEX IF NOT EXISTS idx_health_logs_service_name ON health_logs(service_name);

-- Create partition for recent telemetry data (last 30 days)
CREATE TABLE IF NOT EXISTS telemetry_data_recent (
    LIKE telemetry_data INCLUDING ALL
) PARTITION BY RANGE (timestamp);

-- Create partition for older data
CREATE TABLE IF NOT EXISTS telemetry_data_archive (
    LIKE telemetry_data INCLUDING ALL
);

-- Insert default settings
INSERT INTO settings (key, value, value_type, description, category) VALUES
    ('server.port', '9876', 'integer', 'WebSocket server port', 'server'),
    ('server.api_port', '9877', 'integer', 'REST API port', 'server'),
    ('telemetry.interval', '1000', 'integer', 'Telemetry update interval in ms', 'telemetry'),
    ('telemetry.retention_days', '30', 'integer', 'Data retention period', 'telemetry'),
    ('discovery.enabled', 'true', 'boolean', 'Enable mDNS service discovery', 'discovery'),
    ('log.level', 'Information', 'string', 'Logging level', 'logging'),
    ('cache.enabled', 'true', 'boolean', 'Enable caching', 'cache')
ON CONFLICT (key) DO NOTHING;

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO neonlink;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO neonlink;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_settings_updated_at BEFORE UPDATE ON settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_scripts_updated_at BEFORE UPDATE ON scripts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_connections_updated_at BEFORE UPDATE ON connections
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Comment on database
COMMENT ON DATABASE neonlink IS 'NeonLink Hardware Monitoring System';
