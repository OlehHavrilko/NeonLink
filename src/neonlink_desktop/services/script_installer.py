"""
ScriptInstaller - Script installation service.

Provides methods for installing scripts:
- Copy to target directory
- Create symbolic links
- Add to system PATH
"""

import os
import shutil
from pathlib import Path
from typing import Optional

from ..models.script_model import ScriptModel, ScriptInstallMethod


class InstallationError(Exception):
    """Raised when script installation fails."""
    pass


class ScriptInstaller:
    """
    Script installer with multiple installation methods.
    
    Supports:
    - COPY: Copy script file to target directory
    - SYMLINK: Create symbolic link to script
    - PATH: Add script directory to system PATH
    """
    
    def __init__(self):
        """Initialize ScriptInstaller."""
        pass
    
    def install(
        self,
        script: ScriptModel,
        target_directory: Optional[Path] = None
    ) -> Path:
        """
        Install a script using the specified method.
        
        Args:
            script: Script model with installation settings
            target_directory: Target directory (defaults to ~/.local/bin)
            
        Returns:
            Path to installed script
            
        Raises:
            InstallationError: If installation fails
        """
        target = target_directory or self._get_default_install_dir()
        target.mkdir(parents=True, exist_ok=True)
        
        if script.install_method == ScriptInstallMethod.COPY:
            return self._copy_script(script, target)
        elif script.install_method == ScriptInstallMethod.SYMLINK:
            return self._create_symlink(script, target)
        elif script.install_method == ScriptInstallMethod.PATH:
            return self._add_to_path(script)
        else:
            raise InstallationError(
                f"Unknown install method: {script.install_method}"
            )
    
    def uninstall(
        self,
        script: ScriptModel,
        install_path: Path
    ) -> None:
        """
        Uninstall a previously installed script.
        
        Args:
            script: Script model
            install_path: Path where script was installed
        """
        if script.install_method == ScriptInstallMethod.COPY:
            if install_path.exists():
                install_path.unlink()
        elif script.install_method == ScriptInstallMethod.SYMLINK:
            if install_path.is_symlink() and install_path.exists():
                install_path.unlink()
        elif script.install_method == ScriptInstallMethod.PATH:
            self._remove_from_path(script)
    
    def _copy_script(
        self,
        script: ScriptModel,
        target_dir: Path
    ) -> Path:
        """
        Copy script to target directory.
        
        Args:
            script: Script model
            target_dir: Target directory
            
        Returns:
            Path to copied file
        """
        target_path = target_dir / script.source_path.name
        
        if target_path.exists():
            target_path.unlink()
        
        shutil.copy2(script.source_path, target_path)
        
        # Make executable
        os.chmod(target_path, 0o755)
        
        return target_path
    
    def _create_symlink(
        self,
        script: ScriptModel,
        target_dir: Path
    ) -> Path:
        """
        Create symbolic link to script.
        
        Args:
            script: Script model
            target_dir: Target directory for symlink
            
        Returns:
            Path to symlink
        """
        symlink_name = script.source_path.stem
        if not script.source_path.suffix:
            symlink_name = script.name.replace(' ', '_')
        
        symlink_path = target_dir / symlink_name
        
        # Remove existing symlink
        if symlink_path.is_symlink() or symlink_path.exists():
            symlink_path.unlink()
        
        # Create new symlink (relative or absolute)
        try:
            os.symlink(script.source_path, symlink_path)
        except OSError:
            # Fallback to absolute path on Windows
            os.symlink(script.source_path.resolve(), symlink_path)
        
        return symlink_path
    
    def _add_to_path(self, script: ScriptModel) -> Path:
        """
        Add script directory to system PATH.
        
        Note: This modifies the current process PATH only.
        For permanent changes, shell configuration files must be modified.
        
        Args:
            script: Script model
            
        Returns:
            Path to script
        """
        script_dir = script.source_path.parent
        
        # Add to current process PATH
        current_path = os.environ.get('PATH', '')
        if script_dir.as_posix() not in current_path:
            os.environ['PATH'] = f"{script_dir.as_posix()}{os.pathsep}{current_path}"
        
        return script.source_path
    
    def _remove_from_path(self, script: ScriptModel) -> None:
        """Remove script directory from current process PATH."""
        script_dir = script.source_path.parent
        
        current_path = os.environ.get('PATH', '')
        path_entries = current_path.split(os.pathsep)
        
        script_dir_posix = script_dir.as_posix()
        if script_dir_posix in path_entries:
            path_entries.remove(script_dir_posix)
            os.environ['PATH'] = os.pathsep.join(path_entries)
    
    def _get_default_install_dir(self) -> Path:
        """Get default script installation directory."""
        # Platform-specific defaults
        if sys.platform == 'win32':
            # Windows: %LOCALAPPDATA%\Programs
            return Path.home() / 'AppData' / 'Local' / 'Programs' / 'NeonLink'
        else:
            # Unix: ~/.local/bin
            return Path.home() / '.local' / 'bin'
    
    def make_executable(self, script_path: Path) -> None:
        """
        Make a script file executable.
        
        Args:
            script_path: Path to script file
        """
        if sys.platform != 'win32':
            os.chmod(script_path, 0o755)
        # On Windows, execution depends on file association
    
    def create_desktop_entry(
        self,
        script: ScriptModel,
        exec_path: Path,
        icon_path: Optional[Path] = None
    ) -> Path:
        """
        Create a desktop entry file for the script.
        
        Args:
            script: Script model
            exec_path: Path to executable
            icon_path: Optional path to icon
            
        Returns:
            Path to created desktop entry
        """
        if sys.platform == 'win32':
            # Create shortcut
            return self._create_windows_shortcut(script, exec_path)
        elif sys.platform == 'darwin':
            # Create .app bundle
            return self._create_mac_app_bundle(script, exec_path)
        else:
            # Create .desktop file
            return self._create_linux_desktop_entry(script, exec_path, icon_path)
    
    def _create_linux_desktop_entry(
        self,
        script: ScriptModel,
        exec_path: Path,
        icon_path: Optional[Path]
    ) -> Path:
        """Create Linux .desktop entry file."""
        import configparser
        
        desktop_dir = Path.home() / '.local' / 'share' / 'applications'
        desktop_dir.mkdir(parents=True, exist_ok=True)
        
        desktop_file = desktop_dir / f"neonlink-{script.name.replace(' ', '-')}.desktop"
        
        config = configparser.ConfigParser()
        
        config['Desktop Entry'] = {
            'Type': 'Application',
            'Name': script.name,
            'Comment': script.name,
            'Exec': f"{exec_path}",
            'Icon': str(icon_path) if icon_path else '',
            'Terminal': 'true',
            'Categories': 'NeonLink;'
        }
        
        with open(desktop_file, 'w') as f:
            config.write(f)
        
        return desktop_file
    
    def _create_windows_shortcut(
        self,
        script: ScriptModel,
        exec_path: Path
    ) -> Path:
        """Create Windows shortcut (.lnk file)."""
        import comtypes.client
        
        shortcut_dir = Path.home() / 'Desktop'
        shortcut_path = shortcut_dir / f"{script.name}.lnk"
        
        shell = comtypes.client.CreateObject('WScript.Shell')
        shortcut = shell.CreateShortCut(str(shortcut_path))
        shortcut.Targetpath = str(exec_path)
        shortcut.WorkingDirectory = str(exec_path.parent)
        shortcut.save()
        
        return shortcut_path
    
    def _create_mac_app_bundle(
        self,
        script: ScriptModel,
        exec_path: Path
    ) -> Path:
        """Create macOS .app bundle."""
        app_dir = Path.home() / 'Applications' / 'NeonLink'
        app_dir.mkdir(parents=True, exist_ok=True)
        
        app_path = app_dir / f"{script.name}.app"
        contents_path = app_path / 'Contents'
        macos_path = contents_path / 'MacOS'
        resources_path = contents_path / 'Resources'
        
        macos_path.mkdir(parents=True, exist_ok=True)
        resources_path.mkdir(parents=True, exist_ok=True)
        
        # Create Info.plist
        info_plist = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>{exec_path.name}</string>
    <key>CFBundleIdentifier</key>
    <string>com.neonlink.script.{script.id}</string>
    <key>CFBundleName</key>
    <string>{script.name}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
</dict>
</plist>
"""
        (contents_path / 'Info.plist').write_text(info_plist)
        
        # Copy executable
        shutil.copy2(exec_path, macos_path / exec_path.name)
        
        return app_path


import sys
