#!/usr/bin/env ruby

POSTGIS_VERSION = '3.2.1'

TMP_DIR = File.join(__dir__, '..', 'tmp')

`curl -o #{File.join(TMP_DIR, 'postgis.tar.gz')} https://download.osgeo.org/postgis/source/postgis-#{POSTGIS_VERSION}.tar.gz`
`tar -xjf #{File.join(TMP_DIR, 'postgis.tar.gz')} -C #{TMP_DIR}`

x = Dir.chdir(File.join(TMP_DIR, 'postgis-' + POSTGIS_VERSION, 'postgis')) do
  `cpp -traditional-cpp -w -P postgis.sql.in`
end

# Avoid wrapping transaction (its only used for the SET LOCAL and not necessary)
x.sub!("BEGIN;\nSET LOCAL client_min_messages TO warning;\n", '')
x.sub!("COMMIT;\n", '')

# Prevent invocation of geometry_in for function defaults
x.sub!("default 'POINT EMPTY'::geometry", 'default NULL::geometry') # ST_Angle
x.sub!("DEFAULT 'SRID=3857;LINESTRING(-20037508.342789244 -20037508.342789244, 20037508.342789244 20037508.342789244)'::geometry", 'DEFAULT NULL::geometry') # ST_TileEnvelope
x.gsub!("DEFAULT 'POINT(0 0)'", 'DEFAULT NULL::geometry') # ST_Hexagon and ST_Square

# For now we don't support the PostGIS selectivity helper functions
# (as they'd require running the corresponding C code during planning)
x.gsub!(/(,?\s+)((RESTRICT|JOIN) = gserialized_[\w_]+)/, '')

# Avoid DO blocks that are used for validating the install environment
# (we want to process this without requiring PL/pgSQL function execution)
x.gsub!(/DO \$\$.*?\$\$( LANGUAGE 'plpgsql')?;/m, '')

# TODO: This should probably be context-specific
x.gsub!('@extschema@', 'public')

File.write('postgis_mock.sql', x)
