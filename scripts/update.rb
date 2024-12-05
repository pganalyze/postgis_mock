#!/usr/bin/env ruby

POSTGIS_VERSION = '3.5.0'
POSTGIS_MAJOR   = POSTGIS_VERSION.split('.')[0..1].join('.')
MODULEPATH      = '$libdir/postgis-' + POSTGIS_MAJOR

TMP_DIR = File.join(__dir__, '..', 'tmp')

`curl -o #{File.join(TMP_DIR, 'postgis.tar.gz')} https://download.osgeo.org/postgis/source/postgis-#{POSTGIS_VERSION}.tar.gz`
`tar -xjf #{File.join(TMP_DIR, 'postgis.tar.gz')} -C #{TMP_DIR}`

x = nil

Dir.chdir(File.join(TMP_DIR, 'postgis-' + POSTGIS_VERSION)) do
  `./configure --without-raster`

  Dir.chdir('postgis') do
    # Assume we're running on Postgres 13+
    `sed -I '' -E "s/^(#define POSTGIS_PGSQL_VERSION) .+/\\1 130/" sqldefines.h`
    x = `cpp -traditional-cpp -w -P postgis.sql.in`
  end
end

# Avoid wrapping transaction (its only used for the SET LOCAL and not necessary)
x.sub!("BEGIN;\nSET LOCAL client_min_messages TO warning;\n", '')
x.sub!("COMMIT;\n", '')

# Prevent invocation of geometry_in for function defaults
x.sub!("default 'POINT EMPTY'::geometry", 'default NULL::geometry') # ST_Angle
x.sub!("DEFAULT 'SRID=3857;LINESTRING(-20037508.342789244 -20037508.342789244, 20037508.342789244 20037508.342789244)'::geometry", 'DEFAULT NULL::geometry') # ST_TileEnvelope
x.gsub!(/DEFAULT 'POINT( EMPTY|\(0 0\))'/, 'DEFAULT NULL::geometry') # ST_Hexagon and ST_Square

# For now we don't support the PostGIS selectivity helper functions
# (as they'd require running the corresponding C code during planning)
x.gsub!(/(,?\s+)((RESTRICT|JOIN) = gserialized_[\w_]+)/, '')

# We also don't support the PostGIS index support functions for the same reason
x.gsub!(/\s+SUPPORT postgis_index_supportfn/, '')

# Remove trailing commas resulting from previous substitutions. E.g.:
#
# ```diff
#  CREATE OPERATOR @ (
#         LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_within,
# -       COMMUTATOR = '~',
# +       COMMUTATOR = '~'
#         -- Updated: 3.4.0 to use selectivity estimator,
#         -- Updated: 3.4.0 to use join selectivity estimator
#  );
# ```
x.gsub!(/,(\s*\n(\s*--.*)*\n\))/, '\1')

# Avoid DO blocks that are used for validating the install environment
# (we want to process this without requiring PL/pgSQL function execution)
x.gsub!(/DO \$\$.*?\$\$( LANGUAGE 'plpgsql')?;/m, '')

# Run the same replacements as done by postgis/Makefile.in
x.gsub!("'MODULE_PATHNAME'", "'" + MODULEPATH + "'")
x.gsub!('@extschema@.', '')

File.write('postgis_mock.sql', x)
