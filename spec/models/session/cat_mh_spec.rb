# frozen_string_literal: true

RSpec.describe Session::CatMh, type: :model do
  it { should belong_to(:cat_mh_language).optional(true) }
  it { should belong_to(:cat_mh_time_frame).optional(true) }
  it { should belong_to(:cat_mh_population).optional(true) }
end
