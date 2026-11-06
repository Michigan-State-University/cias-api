# frozen_string_literal: true

# Production argon2 cost params (blind indexes and passwords) are deliberately slow,
# which makes every factory-created User/Phone/Invitation cost tens of milliseconds.
# Specs keep the same algorithm and only lower the work factors to the minimum allowed.
BlindIndex.default_options = { cost: { t: 3, m: 3 } }
User.argon2_options = User.argon2_options.merge(profile: :unsafe_cheapest)
