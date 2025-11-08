# GitHub Copilot Agent Implementation Prompt

## Project: Cool Llama Linux Optimizer - Full Implementation

You are a **Senior Full-Stack Developer** tasked with implementing the complete Cool Llama Linux Optimizer based on the architectural specifications in README.md.

## Implementation Tasks

### Phase 1: Project Foundation (Start Here)

#### 1.1 Create Project Configuration Files

**pyproject.toml** - Modern Python project configuration:
```toml
[build-system]
requires = ["setuptools>=65.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "cool-llama"
version = "1.0.0"
description = "A comprehensive system optimization suite for Linux distributions"
authors = [{name = "Cool Llama Team", email = "team@coollama.dev"}]
license = {text = "MIT"}
readme = "README.md"
requires-python = ">=3.9"
keywords = ["linux", "optimization", "system", "ubuntu", "debian", "performance"]
classifiers = [
    "Development Status :: 4 - Beta",
    "Intended Audience :: System Administrators",
    "License :: OSI Approved :: MIT License",
    "Operating System :: POSIX :: Linux",
    "Programming Language :: Python :: 3.9",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
]

dependencies = [
    "click>=8.1.0",
    "rich>=13.0.0",
    "pyyaml>=6.0",
    "psutil>=5.9.0",
    "distro>=1.8.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "pytest-cov>=4.0.0",
    "pytest-asyncio>=0.21.0",
    "black>=23.0.0",
    "isort>=5.12.0",
    "flake8>=6.0.0",
    "mypy>=1.0.0",
    "pre-commit>=3.0.0",
]

[project.scripts]
cool-llama = "cool_llama.cli:main"
llama = "cool_llama.cli:main"

[tool.black]
line-length = 100
target-version = ['py39']

[tool.isort]
profile = "black"
line_length = 100

[tool.mypy]
python_version = "3.9"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
```

**requirements.txt**:
```
click>=8.1.0
rich>=13.0.0
pyyaml>=6.0
psutil>=5.9.0
distro>=1.8.0
```

**requirements-dev.txt**:
```
-r requirements.txt
pytest>=7.0.0
pytest-cov>=4.0.0
pytest-asyncio>=0.21.0
black>=23.0.0
isort>=5.12.0
flake8>=6.0.0
mypy>=1.0.0
pre-commit>=3.0.0
```

#### 1.2 Create .gitignore
```
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Virtual environments
venv/
ENV/
env/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# Testing
.coverage
.pytest_cache/
htmlcov/

# Logs
*.log
logs/

# OS
.DS_Store
Thumbs.db
```

#### 1.3 Create Makefile
```makefile
.PHONY: install dev test lint format clean

install:
	pip install -e .

dev:
	pip install -e ".[dev]"

test:
	pytest tests/ -v --cov=src/cool_llama --cov-report=html --cov-report=term

lint:
	flake8 src/ tests/
	mypy src/ tests/
	black --check src/ tests/
	isort --check-only src/ tests/

format:
	black src/ tests/
	isort src/ tests/

clean:
	rm -rf build/ dist/ *.egg-info
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
```

### Phase 2: Core Module Implementation

#### 2.1 Create src/cool_llama/__init__.py
```python
"""Cool Llama Linux Optimizer - A comprehensive system optimization suite."""

__version__ = "1.0.0"
__author__ = "Cool Llama Team"
__license__ = "MIT"

from cool_llama.cli import main

__all__ = ["main"]
```

#### 2.2 Create src/cool_llama/cli.py
Implement the main CLI interface with:
- Click-based command structure
- Beautiful Rich console output with cyan theme
- Interactive menu system
- Subcommands: optimize, update, health, backup, benchmark, config
- Global options: --verbose, --dry-run, --config
- Cool Llama ASCII logo display
- Error handling with user-friendly messages

#### 2.3 Create src/cool_llama/config.py
Implement configuration management:
- YAML-based configuration file (~/.config/cool-llama/config.yml)
- Default configuration profiles (conservative, balanced, aggressive)
- Configuration validation
- Profile switching
- Override support via CLI flags

#### 2.4 Create src/cool_llama/core/system.py
Implement system detection and information:
- Distribution detection (Ubuntu, Debian, Fedora, Arch, etc.)
- Kernel version
- CPU information
- Memory statistics
- Disk information and health
- Temperature monitoring
- Load averages
- Systemd service status

#### 2.5 Create src/cool_llama/core/packages.py
Implement package management:
- Multi-package-manager support (apt, dnf, yum, pacman)
- Package list updates
- System upgrades
- Autoremove unused packages
- Cache cleaning
- Snap and Flatpak support
- Package list backups

#### 2.6 Create src/cool_llama/core/optimizer.py
Implement system optimizations:
- Memory management tuning (swappiness, cache pressure)
- I/O scheduler optimization for SSD/HDD
- Systemd journal cleanup
- SSD TRIM operations
- Kernel parameter tuning
- Service optimization
- Startup optimization
- Network tuning
- Safety checks before all operations
- Rollback capability

#### 2.7 Create src/cool_llama/core/monitor.py
Implement health monitoring:
- CPU usage tracking
- Memory usage monitoring
- Disk space alerts
- Temperature warnings
- Failed service detection
- Security updates check
- System load analysis
- Health score calculation

#### 2.8 Create src/cool_llama/utils/logger.py
Implement logging system:
- Structured logging with rotation
- Multiple log levels
- Colored console output
- File and console handlers
- Log file management (/var/log/cool-llama/)
- Audit trail for system changes

#### 2.9 Create src/cool_llama/utils/backup.py
Implement backup functionality:
- Configuration file backups
- Package list snapshots
- System state capture
- Restore capabilities
- Backup rotation
- Backup verification

#### 2.10 Create src/cool_llama/utils/benchmark.py
Implement benchmarking:
- CPU performance tests
- Memory bandwidth tests
- Disk I/O tests
- Network speed tests
- Comparison with baselines
- Performance reporting

#### 2.11 Create src/cool_llama/ui/menu.py
Implement interactive menus:
- Rich-powered TUI
- Main menu navigation
- Submenus for each feature
- Input validation
- Confirmation prompts
- Progress indicators

#### 2.12 Create src/cool_llama/ui/display.py
Implement display utilities:
- ASCII logo in cyan
- Formatted tables
- Progress bars
- Status indicators
- Color-coded messages
- Emoji support for clarity

### Phase 3: Testing

#### 3.1 Create tests/conftest.py
Set up pytest fixtures and configuration

#### 3.2 Create comprehensive tests:
- tests/test_cli.py
- tests/test_config.py
- tests/core/test_system.py
- tests/core/test_packages.py
- tests/core/test_optimizer.py
- tests/core/test_monitor.py
- tests/utils/test_logger.py
- tests/utils/test_backup.py
- tests/utils/test_benchmark.py

Target: >90% code coverage

### Phase 4: DevOps & CI/CD

#### 4.1 Create .github/workflows/ci.yml
Implement CI pipeline:
- Run on push and PR
- Multiple Python versions (3.9, 3.10, 3.11)
- Lint checks (black, isort, flake8, mypy)
- Test execution with coverage
- Coverage reporting

#### 4.2 Create .github/workflows/release.yml
Implement release automation:
- Triggered on version tags
- Build wheel and sdist
- PyPI publishing
- GitHub release creation
- Changelog generation

#### 4.3 Create .pre-commit-config.yaml
Set up pre-commit hooks

### Phase 5: Documentation

#### 5.1 Update README.md with:
- Project badges (CI, coverage, PyPI, license)
- Feature showcase
- Installation instructions
- Quick start guide
- Usage examples with screenshots
- Contributing guidelines
- License information

#### 5.2 Create docs/:
- docs/installation.md
- docs/usage.md
- docs/configuration.md
- docs/api.md
- docs/development.md
- docs/faq.md
- docs/security.md
- docs/changelog.md

#### 5.3 Create CONTRIBUTING.md
Guidelines for contributors

#### 5.4 Create LICENSE
MIT License text

#### 5.5 Create SECURITY.md
Security policy and vulnerability reporting

### Phase 6: Additional Files

#### 6.1 Create config/default.yml
Default configuration template

#### 6.2 Create scripts/install.sh
Installation script for various distributions

#### 6.3 Create scripts/uninstall.sh
Clean uninstallation script

#### 6.4 Create CHANGELOG.md
Version history

## Implementation Guidelines

### Code Quality Standards
1. **Type Hints**: Use comprehensive type hints everywhere
2. **Docstrings**: Google-style docstrings for all public APIs
3. **Error Handling**: Use custom exceptions, never bare except
4. **Logging**: Log all important operations and errors
5. **Testing**: Write tests as you implement features
6. **Security**: Validate all inputs, use subprocess securely
7. **Performance**: Use async where beneficial, optimize hot paths

### Best Practices
- Follow PEP 8 and PEP 257
- Keep functions small and focused
- Use dependency injection for testability
- Implement the Single Responsibility Principle
- Write self-documenting code with clear names
- Add comments only for complex logic
- Use context managers for resource management

### User Experience
- Provide clear, actionable error messages
- Use colors and emojis for visual clarity
- Show progress for long operations
- Confirm destructive actions
- Provide dry-run mode for all operations
- Make common operations one command away

## Deliverables Checklist

- [ ] All project configuration files created
- [ ] Complete source code with type hints and docstrings
- [ ] Comprehensive test suite with >90% coverage
- [ ] CI/CD pipelines configured and working
- [ ] Complete documentation
- [ ] Installation and setup scripts
- [ ] Pre-commit hooks configured
- [ ] LICENSE and SECURITY.md files
- [ ] Working CLI with all features
- [ ] Beautiful TUI with Rich library
- [ ] Safe system modifications with rollback
- [ ] Multi-distribution support

## Success Verification

After implementation, verify:
1. `make dev` installs all dependencies
2. `make test` passes all tests
3. `make lint` passes all checks
4. `cool-llama --help` shows CLI interface
5. `cool-llama optimize --dry-run` works
6. All tests have meaningful assertions
7. Documentation is complete and accurate

---

**Start with Phase 1, then proceed systematically through each phase. Build incrementally, test frequently, and maintain high quality throughout. Let's create something production-ready! 🦙✨🚀**
