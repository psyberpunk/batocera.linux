from __future__ import annotations

import pytest

from batocera_launch.config.es_settings import ESSettings
from batocera_launch.paths import ES_SETTINGS

pytestmark = pytest.mark.usefixtures('fs')


def test_load_without_settings_file_falls_back_to_an_empty_config() -> None:
    # a freshly flashed image has no es_settings.cfg until ES writes one
    assert not ES_SETTINGS.exists()

    settings = ESSettings.load()

    assert settings.get_str('ThemeSet') is None
    assert settings.get_int('MaxVRAM', 100) == 100
    assert settings.get_bool('VSync') is False


def test_load_reads_values_from_the_settings_file() -> None:
    ES_SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    ES_SETTINGS.write_text(
        '<?xml version="1.0"?>\n'
        '<config>\n'
        '  <string name="ThemeSet" value="carbon" />\n'
        '  <int name="MaxVRAM" value="256" />\n'
        '  <bool name="VSync" value="true" />\n'
        '</config>\n'
    )

    settings = ESSettings.load()

    assert settings.get_str('ThemeSet') == 'carbon'
    assert settings.get_int('MaxVRAM') == 256
    assert settings.get_bool('VSync') is True
