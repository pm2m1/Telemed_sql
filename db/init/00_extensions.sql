-- Enable required PostgreSQL extensions
-- This file runs first to ensure extensions are available for subsequent scripts

-- UUID generation support
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Trigram support for fuzzy text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- GiST operator classes for scalar types used by exclusion constraints
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Verify extensions are loaded
SELECT 
    extname as extension_name,
    extversion as version
FROM pg_extension 
WHERE extname IN ('uuid-ossp', 'pg_trgm', 'btree_gist')
ORDER BY extname;

