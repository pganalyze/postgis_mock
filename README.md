# PostGIS mock

This repository contains a simplified version of the PostGIS extension
functions, types and operators, to be used for parsing/planning queries that
depend on PostGIS APIs, but without calling actual PostGIS code.

Some operator and type definitions have been changed to support this, see
comments in `scripts/update.rb`.


## Updating the definitions to new PostGIS versions

1. Modify `scripts/update.rb` to the desired PostGIS version
2. Run the Ruby script to download PostGIS and generate the modified
   `postgis_mock.sql` extension script:

```sh
scripts/update.rb
```

3. Commit the updated `postgis_mock.sql` file to this repository


## License

Scripts and supporting files:<br />
Copyright (c) 2022, pganalyze Team <team@pganalyze.com>

PostGIS extension functions, types and operators:<br />
Copyright 2001-2003 Refractions Research Inc.

This repository is GPL v2 (or later) licensed, due to PostGIS itself being
GPL v2 (or later) licensed, see COPYING file for details.
