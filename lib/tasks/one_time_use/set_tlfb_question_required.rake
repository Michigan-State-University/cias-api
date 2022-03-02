
namespace :tlfb do
  desc 'Sets required on tlfb question'
  task set_required: :environment do
    Question::TlfbQuestion.all.each do |question| 
      question.update!(settings: {"image"=>false, "title"=>false, "video"=>false, "required"=>true, "subtitle"=>false, "narrator_skippable"=>false})
    end
  end
end
