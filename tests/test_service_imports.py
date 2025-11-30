"""Import sanity checks for all service skeletons.

This test verifies that all service packages can be imported successfully.
"""

import sys
from pathlib import Path


def test_import_nc_data_pipeline():
    """Test that nc_data_pipeline package can be imported."""
    # Add services to path
    services_path = Path(__file__).parent.parent / "services" / "nc-data-pipeline" / "src"
    sys.path.insert(0, str(services_path))
    
    try:
        import nc_data_pipeline
        assert hasattr(nc_data_pipeline, "__version__")
    finally:
        sys.path.pop(0)


def test_import_nc_core():
    """Test that nc_core package can be imported."""
    services_path = Path(__file__).parent.parent / "services" / "nc-core" / "src"
    sys.path.insert(0, str(services_path))
    
    try:
        import nc_core
        assert hasattr(nc_core, "__version__")
        assert nc_core.__version__ == "0.1.0"
    finally:
        sys.path.pop(0)


def test_import_nc_audithound_api():
    """Test that nc_audithound_api package can be imported."""
    services_path = Path(__file__).parent.parent / "services" / "nc-audithound-api" / "src"
    sys.path.insert(0, str(services_path))
    
    try:
        import nc_audithound_api
        assert hasattr(nc_audithound_api, "__version__")
        assert nc_audithound_api.__version__ == "0.1.0"
    finally:
        sys.path.pop(0)


def test_import_nc_agent_forge():
    """Test that nc_agent_forge package can be imported."""
    services_path = Path(__file__).parent.parent / "services" / "nc-agent-forge" / "src"
    sys.path.insert(0, str(services_path))
    
    try:
        import nc_agent_forge
        assert hasattr(nc_agent_forge, "__version__")
        assert nc_agent_forge.__version__ == "0.1.0"
    finally:
        sys.path.pop(0)


def test_import_nc_mcp_server():
    """Test that nc_mcp_server package can be imported."""
    services_path = Path(__file__).parent.parent / "services" / "nc-mcp-server" / "src"
    sys.path.insert(0, str(services_path))
    
    try:
        import nc_mcp_server
        assert hasattr(nc_mcp_server, "__version__")
        assert nc_mcp_server.__version__ == "0.1.0"
    finally:
        sys.path.pop(0)
