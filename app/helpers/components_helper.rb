module ComponentsHelper
  def component(path, *params, &block)
    render("components/#{path}", *params, &block)
  end
end
