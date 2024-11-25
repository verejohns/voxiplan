Shortener.unique_key_length = 8
Shortener.forbidden_keys.concat %w(terms promo)
Shortener.ignore_robots = true
Shortener.charset = :alphanumcase