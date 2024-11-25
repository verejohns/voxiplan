module Api
  class TemplatesController < Api::BaseController
    def index
      if !action
        render json: {result: current_ivr.templates}, status: 200
      elsif !templates[action]
        render json: {result: "No such template: #{action}"}, status: 404
      else
        render json: {result: current_ivr.templates[action][locale]}, status: 200
      end
    end

    def create
      if action.nil? || params[:text].nil?
        render json: {result: "Missing bot_action or text"}, status: 422 and return
      end

      templates[action] ||= {}
      templates[action][locale] = params[:text]
      if current_ivr.save
        render json: {result: templates.slice(action)}, status: 201
      else
        render json: {result: "Error"}, status: 422
      end
    end

    private

    def templates
      current_ivr.templates
    end

    def action
      params[:bot_action]
    end

    def locale
      params[:locale] ||= 'en'
    end

  end
end