# frozen_string_literal: true

notification :off

guard 'rake', task: 'docs:build' do
  watch(%r{^docs/.+$})
end

guard 'livereload' do
  extensions = {
    css: :css,
    scss: :css,
    sass: :css,
    js: :js,
    coffee: :js,
    html: :html,
    png: :png,
    gif: :gif,
    jpg: :jpg,
    jpeg: :jpeg
  }
  compiled_exts = extensions.values.uniq
  watch(%r{/public/docs/.+\.(#{compiled_exts * '|'})}) { 'http://localhost:3000/docs' }
end
