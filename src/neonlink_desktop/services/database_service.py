"""
DatabaseService - SQLite database for application logging.

Provides async SQLite database operations for persistent logging
with filtering, search, and export capabilities.
"""

import asyncio
import aiosqlite
import json
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager

from models.log_entry import LogEntry, LogLevel


class DatabaseService:
    """
    Async SQLite database service for application logging.
    
    Database path: ~/.config/neonlink/logs.db
    
    Tables:
        - logs: Application log entries
        - metadata: Database metadata and settings
    """
    
    DB_PATH = Path.home() / '.config' / 'neonlink' / 'logs.db'
    
    # Table creation SQL
    CREATE_LOGS_TABLE = """
        CREATE TABLE IF NOT EXISTS logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            level TEXT NOT NULL,
            source TEXT NOT NULL,
            message TEXT NOT NULL,
            script_id TEXT,
            details TEXT,
            line_number INTEGER
        );
    """
    
    CREATE_INDEXES = [
        "CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON logs(timestamp);",
        "CREATE INDEX IF NOT EXISTS idx_logs_level ON logs(level);",
        "CREATE INDEX IF NOT EXISTS idx_logs_script_id ON logs(script_id);",
        "CREATE INDEX IF NOT EXISTS idx_logs_source ON logs(source);",
    ]
    
    CREATE_METADATA_TABLE = """
        CREATE TABLE IF NOT EXISTS metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
    """
    
    def __init__(self, db_path: Optional[Path] = None):
        """
        Initialize DatabaseService.
        
        Args:
            db_path: Optional custom database path
        """
        self.db_path = db_path or self.DB_PATH
        self._connection: Optional[aiosqlite.Connection] = None
        self._lock = asyncio.Lock()
        
    async def initialize(self) -> None:
        """Initialize database connection and create tables."""
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        
        self._connection = await aiosqlite.connect(
            self.db_path,
            isolation_level=None  # Enable async context managers
        )
        
        # Enable foreign keys and WAL mode for better performance
        await self._connection.execute("PRAGMA journal_mode=WAL;")
        await self._connection.execute("PRAGMA synchronous=NORMAL;")
        
        # Create tables
        await self._connection.execute(self.CREATE_LOGS_TABLE)
        await self._connection.execute(self.CREATE_METADATA_TABLE)
        
        # Create indexes
        for index_sql in self.CREATE_INDEXES:
            await self._connection.execute(index_sql)
        
        await self._connection.commit()
    
    async def close(self) -> None:
        """Close database connection."""
        if self._connection:
            await self._connection.close()
            self._connection = None
    
    @asynccontextmanager
    async def connection(self):
        """Async context manager for database operations."""
        async with self._lock:
            if not self._connection:
                await self.initialize()
            yield self._connection
    
    async def add_log(self, entry: LogEntry) -> int:
        """
        Add a log entry to the database.
        
        Args:
            entry: LogEntry instance to save
            
        Returns:
            ID of the inserted row
        """
        async with self.connection() as conn:
            cursor = await conn.execute(
                """
                INSERT INTO logs (timestamp, level, source, message, script_id, details, line_number)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    entry.timestamp.isoformat(),
                    entry.level.value,
                    entry.source or "system",
                    entry.message,
                    entry.script_id,
                    json.dumps({"message": entry.message}) if entry.message else None,
                    entry.line_number,
                )
            )
            await conn.commit()
            return cursor.lastrowid
    
    async def add_logs_batch(self, entries: List[LogEntry]) -> int:
        """
        Add multiple log entries in a single transaction.
        
        Args:
            entries: List of LogEntry instances
            
        Returns:
            Number of inserted entries
        """
        if not entries:
            return 0
            
        async with self.connection() as conn:
            data = [
                (
                    entry.timestamp.isoformat(),
                    entry.level.value,
                    entry.source or "system",
                    entry.message,
                    entry.script_id,
                    json.dumps({"message": entry.message}) if entry.message else None,
                    entry.line_number,
                )
                for entry in entries
            ]
            
            await conn.executemany(
                """
                INSERT INTO logs (timestamp, level, source, message, script_id, details, line_number)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                data
            )
            await conn.commit()
            return len(entries)
    
    async def get_logs(
        self,
        level: Optional[LogLevel] = None,
        source: Optional[str] = None,
        script_id: Optional[str] = None,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
        search_text: Optional[str] = None,
        limit: int = 1000,
        offset: int = 0,
    ) -> List[LogEntry]:
        """
        Get log entries with filtering.
        
        Args:
            level: Filter by log level
            source: Filter by source
            script_id: Filter by script ID
            start_time: Filter by start timestamp
            end_time: Filter by end timestamp
            search_text: Full-text search in message
            limit: Maximum number of entries
            offset: Number of entries to skip
            
        Returns:
            List of filtered LogEntry instances
        """
        query = "SELECT * FROM logs WHERE 1=1"
        params = []
        
        if level:
            query += " AND level = ?"
            params.append(level.value)
        
        if source:
            query += " AND source = ?"
            params.append(source)
        
        if script_id:
            query += " AND script_id = ?"
            params.append(script_id)
        
        if start_time:
            query += " AND timestamp >= ?"
            params.append(start_time.isoformat())
        
        if end_time:
            query += " AND timestamp <= ?"
            params.append(end_time.isoformat())
        
        if search_text:
            query += " AND message LIKE ?"
            params.append(f"%{search_text}%")
        
        query += " ORDER BY timestamp DESC LIMIT ? OFFSET ?"
        params.extend([limit, offset])
        
        async with self.connection() as conn:
            conn.row_factory = aiosqlite.Row
            cursor = await conn.execute(query, params)
            rows = await cursor.fetchall()
            
        entries = []
        for row in rows:
            entries.append(LogEntry(
                timestamp=datetime.fromisoformat(row['timestamp']),
                level=LogLevel(row['level']),
                message=row['message'],
                source=row['source'],
                script_id=row['script_id'],
                line_number=row['line_number'],
            ))
        
        return entries
    
    async def get_log_count(
        self,
        level: Optional[LogLevel] = None,
        source: Optional[str] = None,
        script_id: Optional[str] = None,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
        search_text: Optional[str] = None,
    ) -> int:
        """
        Get count of log entries matching filters.
        
        Args:
            Same as get_logs
            
        Returns:
            Number of matching entries
        """
        query = "SELECT COUNT(*) as count FROM logs WHERE 1=1"
        params = []
        
        if level:
            query += " AND level = ?"
            params.append(level.value)
        
        if source:
            query += " AND source = ?"
            params.append(source)
        
        if script_id:
            query += " AND script_id = ?"
            params.append(script_id)
        
        if start_time:
            query += " AND timestamp >= ?"
            params.append(start_time.isoformat())
        
        if end_time:
            query += " AND timestamp <= ?"
            params.append(end_time.isoformat())
        
        if search_text:
            query += " AND message LIKE ?"
            params.append(f"%{search_text}%")
        
        async with self.connection() as conn:
            cursor = await conn.execute(query, params)
            row = await cursor.fetchone()
            
        return row['count'] if row else 0
    
    async def get_log_sources(self) -> List[str]:
        """
        Get list of all unique log sources.
        
        Returns:
            List of source names
        """
        async with self.connection() as conn:
            cursor = await conn.execute(
                "SELECT DISTINCT source FROM logs ORDER BY source"
            )
            rows = await cursor.fetchall()
            
        return [row[0] for row in rows]
    
    async def get_log_count_by_level(self) -> Dict[LogLevel, int]:
        """
        Get count of logs grouped by level.
        
        Returns:
            Dictionary mapping LogLevel to count
        """
        async with self.connection() as conn:
            cursor = await conn.execute(
                "SELECT level, COUNT(*) as count FROM logs GROUP BY level"
            )
            rows = await cursor.fetchall()
            
        result = {}
        for row in rows:
            try:
                level = LogLevel(row[0])
                result[level] = row[1]
            except ValueError:
                continue
                
        return result
    
    async def delete_old_logs(self, days: int = 30) -> int:
        """
        Delete logs older than specified days.
        
        Args:
            days: Number of days to keep
            
        Returns:
            Number of deleted entries
        """
        cutoff_date = datetime.now() - timedelta(days=days)
        
        async with self.connection() as conn:
            cursor = await conn.execute(
                "DELETE FROM logs WHERE timestamp < ?",
                (cutoff_date.isoformat(),)
            )
            await conn.commit()
            
        return cursor.rowcount
    
    async def clear_logs(self) -> int:
        """
        Clear all log entries.
        
        Returns:
            Number of deleted entries
        """
        async with self.connection() as conn:
            cursor = await conn.execute("DELETE FROM logs")
            await conn.commit()
            
        return cursor.rowcount
    
    async def export_to_text(self, filepath: Path) -> int:
        """
        Export logs to plain text file.
        
        Args:
            filepath: Output file path
            
        Returns:
            Number of exported entries
        """
        entries = await self.get_logs(limit=100000)
        
        lines = []
        for entry in reversed(entries):  # Chronological order
            lines.append(entry.to_display_string())
        
        filepath.write_text('\n'.join(lines), encoding='utf-8')
        
        return len(entries)
    
    async def export_to_json(self, filepath: Path) -> int:
        """
        Export logs to JSON file.
        
        Args:
            filepath: Output file path
            
        Returns:
            Number of exported entries
        """
        entries = await self.get_logs(limit=100000)
        
        data = [
            {
                "timestamp": entry.timestamp.isoformat(),
                "level": entry.level.value,
                "source": entry.source,
                "message": entry.message,
                "script_id": entry.script_id,
                "line_number": entry.line_number,
            }
            for entry in entries
        ]
        
        filepath.write_text(
            json.dumps(data, indent=2, ensure_ascii=False),
            encoding='utf-8'
        )
        
        return len(entries)
    
    async def export_to_csv(self, filepath: Path) -> int:
        """
        Export logs to CSV file.
        
        Args:
            filepath: Output file path
            
        Returns:
            Number of exported entries
        """
        entries = await self.get_logs(limit=100000)
        
        import csv
        
        with open(filepath, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow([
                'timestamp', 'level', 'source', 'message', 'script_id', 'line_number'
            ])
            
            for entry in entries:
                writer.writerow([
                    entry.timestamp.isoformat(),
                    entry.level.value,
                    entry.source,
                    entry.message,
                    entry.script_id,
                    entry.line_number,
                ])
        
        return len(entries)
    
    async def get_database_size(self) -> int:
        """
        Get database file size in bytes.
        
        Returns:
            Database file size
        """
        if self.db_path.exists():
            return self.db_path.stat().st_size
        return 0
    
    async def vacuum(self) -> None:
        """Optimize database by vacuuming."""
        async with self.connection() as conn:
            await conn.execute("VACUUM")


# Singleton instance
_db_service: Optional[DatabaseService] = None


async def get_database_service() -> DatabaseService:
    """
    Get singleton DatabaseService instance.
    
    Returns:
        DatabaseService instance
    """
    global _db_service
    
    if _db_service is None:
        _db_service = DatabaseService()
        await _db_service.initialize()
    
    return _db_service


async def close_database_service() -> None:
    """Close singleton database service."""
    global _db_service
    
    if _db_service:
        await _db_service.close()
        _db_service = None
