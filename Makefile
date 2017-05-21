# pg_geekspeak_calendar/Makefile

EXTENSION = geekspeak_calendar        # the extensions name
DATA = geekspeak_calendar--1.0.0.sql  # script files to install
REGRESS = geekspeak_calendar_test     # unit and regression tests

# postgres build stuff
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
