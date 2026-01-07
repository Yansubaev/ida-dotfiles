#!/usr/bin/env python3
"""
IDA Theme Builder

Generates semantic theme files with override support.
Reads base palette from wallust, applies user overrides, and generates
all theme files for terminals, Hyprland, Waybar, Wofi, etc.
"""

import argparse
import colorsys
import json
import re
import sys
from pathlib import Path
from typing import Dict, Optional, Tuple


class ColorValidator:
    """Validates and normalizes hex color codes."""
    
    HEX_PATTERN = re.compile(r'^#?([0-9A-Fa-f]{6})$')
    
    @classmethod
    def validate(cls, color: str, context: str = "") -> str:
        """
        Validate hex color and return normalized form with #.
        
        Args:
            color: Hex color string (with or without #)
            context: Context for error message
            
        Returns:
            Normalized hex color with #
            
        Raises:
            ValueError: If color is invalid
        """
        if not color:
            raise ValueError(f"Empty color value{' in ' + context if context else ''}")
        
        match = cls.HEX_PATTERN.match(color.strip())
        if not match:
            raise ValueError(
                f"Invalid hex color '{color}'{' in ' + context if context else ''}\n"
                f"Expected format: #RRGGBB or RRGGBB (e.g., #ff5f5f or ff5f5f)"
            )
        
        return f"#{match.group(1).upper()}"
    
    @classmethod
    def strip_hash(cls, color: str) -> str:
        """Remove # from hex color."""
        return color.lstrip('#')
    
    @classmethod
    def to_rgba(cls, color: str, alpha: str = "FF") -> str:
        """Convert hex color to RRGGBBAA format (no #) for Hyprland."""
        return cls.strip_hash(color) + alpha


class ColorUtils:
    """Utilities for color manipulation."""
    
    @staticmethod
    def lighten(hex_color: str, amount: float) -> str:
        """
        Lighten a hex color by the given amount.
        
        Args:
            hex_color: Hex color with #
            amount: Amount to lighten (0.0-1.0)
            
        Returns:
            Lightened hex color with #
        """
        # Parse hex
        hex_clean = hex_color.lstrip('#')
        r, g, b = int(hex_clean[0:2], 16), int(hex_clean[2:4], 16), int(hex_clean[4:6], 16)
        
        # Convert to HLS
        h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
        
        # Lighten
        l = min(1.0, l + amount)
        
        # Convert back to RGB
        r, g, b = colorsys.hls_to_rgb(h, l, s)
        r, g, b = int(r * 255), int(g * 255), int(b * 255)
        
        return f"#{r:02x}{g:02x}{b:02x}"


class OverrideManager:
    """Manages semantic color overrides from config files."""
    
    def __init__(self, global_path: Path, per_theme_path: Path, verbose: bool = False):
        self.global_path = global_path
        self.per_theme_path = per_theme_path
        self.verbose = verbose
    
    def read_overrides(self, filepath: Path) -> Dict[str, str]:
        """
        Read KEY=VALUE overrides from file.
        
        Args:
            filepath: Path to overrides file
            
        Returns:
            Dict of key -> hex color
        """
        overrides = {}
        
        if not filepath.exists():
            return overrides
        
        line_num = 0
        for line in filepath.read_text().splitlines():
            line_num += 1
            # Skip comments and empty lines
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            
            # Parse KEY=VALUE
            if '=' not in line:
                continue
            
            key, value = line.split('=', 1)
            key = key.strip()
            value = value.strip()
            
            if not key or not value:
                continue
            
            # Validate hex color
            try:
                value = ColorValidator.validate(value, f"{filepath.name} line {line_num}")
                overrides[key] = value
            except ValueError as e:
                print(f"Warning: {e}", file=sys.stderr)
                continue
        
        return overrides
    
    def apply_overrides(self, defaults: Dict[str, str]) -> Dict[str, str]:
        """
        Apply overrides with precedence: defaults < global < per-theme.
        
        Args:
            defaults: Default semantic colors from wallust
            
        Returns:
            Merged semantic colors
        """
        result = defaults.copy()
        
        # Apply global overrides
        global_overrides = self.read_overrides(self.global_path)
        for key, value in global_overrides.items():
            semantic_key = key.replace('IDA_', '').lower()
            if semantic_key in result:
                if self.verbose:
                    print(f"  Global override: {semantic_key} = {value}")
                result[semantic_key] = value
        
        # Apply per-theme overrides (highest priority)
        per_theme_overrides = self.read_overrides(self.per_theme_path)
        for key, value in per_theme_overrides.items():
            semantic_key = key.replace('IDA_', '').lower()
            if semantic_key in result:
                if self.verbose:
                    print(f"  Per-theme override: {semantic_key} = {value}")
                result[semantic_key] = value
        
        return result


class ThemeBuilder:
    """Main theme builder orchestrating all generation."""
    
    def __init__(self, cache_dir: Path, repo_root: Path, theme_id: str, verbose: bool = False):
        self.cache_dir = cache_dir
        self.current_dir = cache_dir / "current"
        self.theme_dir = cache_dir / "themes" / theme_id
        self.repo_root = repo_root
        self.theme_id = theme_id
        self.verbose = verbose
        
        self.templates_dir = repo_root / "scripts" / "theme" / "templates"
    
    def log(self, message: str):
        """Log message if verbose mode enabled."""
        if self.verbose:
            print(f"[Builder] {message}")
    
    def read_theme_data(self) -> Dict:
        """Read theme.json and semantic.json in one pass."""
        self.log("Reading theme data...")
        
        theme_json_path = self.current_dir / "theme.json"
        semantic_json_path = self.current_dir / "semantic.json"
        
        if not theme_json_path.exists():
            raise FileNotFoundError(f"Theme file not found: {theme_json_path}")
        
        if not semantic_json_path.exists():
            raise FileNotFoundError(f"Semantic file not found: {semantic_json_path}")
        
        theme = json.loads(theme_json_path.read_text())
        semantic = json.loads(semantic_json_path.read_text())
        
        self.log(f"  Loaded theme: {len(theme.get('colors', []))} colors")
        self.log(f"  Loaded semantic: {len(semantic)} keys")
        
        return {"theme": theme, "semantic": semantic}
    
    def apply_overrides(self, semantic: Dict[str, str]) -> Dict[str, str]:
        """Apply user overrides to semantic colors."""
        self.log("Applying semantic overrides...")
        
        global_override = Path.home() / ".config" / "ida-theme" / "overrides.conf"
        per_theme_override = self.theme_dir / "overrides.conf"
        
        manager = OverrideManager(global_override, per_theme_override, self.verbose)
        return manager.apply_overrides(semantic)
    
    def render_template(self, template_name: str, data: Dict) -> str:
        """
        Render template with simple string substitution.
        
        Args:
            template_name: Template filename
            data: Variables for substitution
            
        Returns:
            Rendered content
        """
        template_path = self.templates_dir / template_name
        if not template_path.exists():
            raise FileNotFoundError(f"Template not found: {template_path}")
        
        content = template_path.read_text()
        
        # Simple substitution: {key} -> value
        for key, value in data.items():
            content = content.replace(f"{{{key}}}", str(value))
        
        return content
    
    def generate_fish_theme(self, data: Dict):
        """Generate fish theme file."""
        self.log("Generating fish-theme.fish...")
        
        theme = data["theme"]
        semantic = data["semantic"]
        
        template_data = {
            "fg": ColorValidator.strip_hash(theme["foreground"]),
            "urgent": ColorValidator.strip_hash(semantic["urgent"]),
            "color8": ColorValidator.strip_hash(theme["colors"][8]),
        }
        
        content = self.render_template("fish-theme.fish.tmpl", template_data)
        output_path = self.current_dir / "fish-theme.fish"
        output_path.write_text(content)
        
        self.log(f"  Written: {output_path}")
    
    def generate_wofi_colors(self, data: Dict):
        """Generate wofi color definitions."""
        self.log("Generating wofi-colors.css...")
        
        theme = data["theme"]
        semantic = data["semantic"]
        
        bg = theme["background"]
        bg_alt = ColorUtils.lighten(bg, 0.08)
        bg_hover = ColorUtils.lighten(bg, 0.18)
        
        template_data = {
            "bg": bg,
            "bg_alt": bg_alt,
            "bg_hover": bg_hover,
            "fg": theme["foreground"],
            "accent": semantic["accent"],
            "color5": theme["colors"][5],
            "urgent": semantic["urgent"],
            "warning": semantic["warning"],
            "success": semantic["success"],
            "info": semantic["info"],
        }
        
        content = self.render_template("wofi-colors.css.tmpl", template_data)
        output_path = self.current_dir / "wofi-colors.css"
        output_path.write_text(content)
        
        self.log(f"  Written: {output_path}")
    
    def generate_semantic_conf(self, semantic: Dict):
        """Generate Hyprland semantic config."""
        self.log("Generating ida-semantic.conf...")
        
        template_data = {
            "accent_rgba": ColorValidator.to_rgba(semantic["accent"]),
            "accent2_rgba": ColorValidator.to_rgba(semantic["accent2"]),
            "warning_rgba": ColorValidator.to_rgba(semantic["warning"]),
            "urgent_rgba": ColorValidator.to_rgba(semantic["urgent"]),
        }
        
        content = self.render_template("ida-semantic.conf.tmpl", template_data)
        output_path = self.current_dir / "ida-semantic.conf"
        output_path.write_text(content)
        
        self.log(f"  Written: {output_path}")
    
    def generate_semantic_css(self, semantic: Dict):
        """Generate CSS semantic variables."""
        self.log("Generating ida-semantic.css...")
        
        content = self.render_template("ida-semantic.css.tmpl", semantic)
        output_path = self.current_dir / "ida-semantic.css"
        output_path.write_text(content)
        
        self.log(f"  Written: {output_path}")
    
    def generate_semantic_fish(self, semantic: Dict):
        """Generate Fish semantic variables."""
        self.log("Generating ida-semantic.fish...")
        
        content = self.render_template("ida-semantic.fish.tmpl", semantic)
        output_path = self.current_dir / "ida-semantic.fish"
        output_path.write_text(content)
        
        self.log(f"  Written: {output_path}")
    
    def build(self):
        """Main build process."""
        self.log(f"Building theme: {self.theme_id}")
        
        # Read base theme data
        data = self.read_theme_data()
        
        # Apply overrides
        semantic = self.apply_overrides(data["semantic"])
        
        # Validate all semantic colors
        self.log("Validating semantic colors...")
        for key, value in semantic.items():
            try:
                semantic[key] = ColorValidator.validate(value, f"semantic.{key}")
            except ValueError as e:
                print(f"Error: {e}", file=sys.stderr)
                sys.exit(1)
        
        # Update data with overridden semantic colors
        data["semantic"] = semantic
        
        # Generate all theme files
        self.generate_fish_theme(data)
        self.generate_wofi_colors(data)
        self.generate_semantic_conf(semantic)
        self.generate_semantic_css(semantic)
        self.generate_semantic_fish(semantic)
        
        self.log("Build complete!")


def main():
    parser = argparse.ArgumentParser(
        description="IDA Theme Builder - Generate semantic theme files"
    )
    parser.add_argument(
        "--cache-dir",
        type=Path,
        required=True,
        help="Theme cache directory (~/.cache/ida-theme)"
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        required=True,
        help="Repository root directory (~/ida)"
    )
    parser.add_argument(
        "--theme-id",
        type=str,
        required=True,
        help="Theme identifier (e.g., wallpaper-sha)"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose output"
    )
    
    args = parser.parse_args()
    
    try:
        builder = ThemeBuilder(
            args.cache_dir,
            args.repo_root,
            args.theme_id,
            args.verbose
        )
        builder.build()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
