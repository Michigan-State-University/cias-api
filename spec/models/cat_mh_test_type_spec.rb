# frozen_string_literal: true

RSpec.describe CatMhTestType, type: :model do
  it { should have_many(:cat_mh_languages) }
  it { should have_many(:cat_mh_time_frames) }
  it { should belong_to(:cat_mh_population) }
end
