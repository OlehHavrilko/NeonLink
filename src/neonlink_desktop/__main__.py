"""
Entry point for NeonLink Desktop Control Center.

Usage:
    python -m neonlink_desktop
    python -m neonlink_desktop --debug
    python -m neonlink_desktop --theme light
"""

import argparse
import sys
import os

# Add src directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from neonlink_desktop.app import NeonLinkApp


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="NeonLink Desktop Control Center",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python -m neonlink_desktop           # Start with default dark theme
    python -m neonlink_desktop --debug  # Start with debug logging
    python -m neonlink_desktop --theme light  # Start with light theme
        """
    )
    
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug logging"
    )
    parser.add_argument(
        "--theme",
        choices=["dark", "light"],
        default="dark",
        help="UI theme (default: dark)"
    )
    parser.add_argument(
        "--profile",
        type=str,
        help="Connection profile to auto-connect"
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"NeonLink Desktop {NeonLinkApp.version}"
    )
    
    return parser.parse_args()


def main() -> int:
    """Main entry point."""
    args = parse_args()
    
    try:
        app = NeonLinkApp(
            debug=args.debug,
            theme=args.theme
        )
        return app.run()
    except KeyboardInterrupt:
        print("\nApplication interrupted by user")
        return 130
    except Exception as e:
        print(f"Fatal error: {e}", file=sys.stderr)
        if args.debug:
            import traceback
            traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
