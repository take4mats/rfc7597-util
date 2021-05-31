desc 'something like rake routes of Rails'
task 'routes' do
  require './main'
  MapeWebApp.class_eval do
    routes = instance_variable_get(:@routes)
    routes.each do |verb, signatures|
      next if verb == 'HEAD'
      signatures.each do |signature|
        path = signature[0].to_s
        path.sub!(/^\(\?-mix:(\\A)?\\/, '')
        path.sub!(/(\\z)?\)$/, '')
        puts format('%-6<verb>s %<path>s', verb: verb, path: path)
      end
    end
  end
end
