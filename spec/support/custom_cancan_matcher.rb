# frozen_string_literal: true

# Custom rspec matcher for testing CanCan abilities.
# Originally inspired by https://github.com/ryanb/cancan/wiki/Testing-Abilities
#
# Usage:
#   should have_abilities(:create, Post.new)
#   should have_abilities([:read, :update], post)
#   should have_abilities({manage: false, destroy: true}, post)
#   should have_abilities({create: false}, Post.new)
#   should not_have_abilities(:update, post)
#   should not_have_abilities([:update, :destroy], post)
#
# WARNING: never use "should_not have_abilities" or you may get false positives due to
# allowlisting/denylisting issues. Use "should not_have_abilities" instead.
RSpec::Matchers.define :have_abilities do |actions, obj|
  include HaveAbilitiesMixin

  match do |ability|
    verify_ability_type(ability)
    @expected_hash = build_expected_hash(actions, default_expectation: true)
    @obj = obj
    @actual_hash = {}
    @expected_hash.each_key do |action|
      @actual_hash[action] = ability.can?(action, obj)
    end
    @actual_hash == @expected_hash
  end

  description do
    obj_name = @obj.class.name
    obj_name = @obj.to_s.capitalize if [Class, Module, Symbol].include?(@obj.class)
    "have abilities #{@expected_hash.keys.join(', ')} on #{obj_name}"
  end

  failure_message do |_ability|
    obj_name = @obj.class.name
    obj_name = @obj.to_s.capitalize if [Class, Module, Symbol].include?(@obj.class)
    <<~MESSAGE
      expected user to have abilities: #{@expected_hash} for
      #{obj_name}, but got #{@actual_hash}
    MESSAGE
  end
end

RSpec::Matchers.define :not_have_abilities do |actions, obj|
  include HaveAbilitiesMixin

  match do |ability|
    verify_ability_type(ability)
    raise ArgumentError, 'You cannot pass a hash to not_have_abilities. Use have_abilities instead.' if actions.is_a?(Hash)

    @expected_hash = build_expected_hash(actions, default_expectation: false)
    @obj = obj
    @actual_hash = {}
    @expected_hash.each_key do |action|
      @actual_hash[action] = ability.can?(action, obj)
    end
    @actual_hash == @expected_hash
  end

  description do
    obj_name = @obj.class.name
    obj_name = @obj.to_s.capitalize if [Class, Module, Symbol].include?(@obj.class)
    "not have abilities #{@expected_hash.keys.join(', ')} on #{obj_name}" if @expected_hash.present?
  end

  failure_message do |_ability|
    obj_name = @obj.class.name
    obj_name = @obj.to_s.capitalize if [Class, Module, Symbol].include?(@obj.class)
    <<~MESSAGE
      expected user NOT to have abilities #{@expected_hash.keys.join(', ')} for
      #{obj_name}, but got #{@actual_hash}
    MESSAGE
  end
end

module HaveAbilitiesMixin
  def build_expected_hash(actions, default_expectation:)
    return actions if actions.is_a?(Hash)

    expected_hash = {}
    case actions
    when is_a?(Array)
      # If given an array like [:create, read] build a hash like:
      # {create: default_expectation, read: default_expectation}
      actions.each { |action| expected_hash[action] = default_expectation }
    when is_a?(Symbol)
      # Build a hash if it's just a symbol.
      expected_hash = { actions => default_expectation }
    end
    expected_hash
  end

  def verify_ability_type(ability)
    raise TypeError, "subject must mixin CanCan::Ability, got a #{ability.class.name} class." unless ability.class.ancestors.include?(CanCan::Ability)
  end
end
