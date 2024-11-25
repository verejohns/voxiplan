require 'rails_helper'

RSpec.describe ReportsController, type: :controller do
  let(:client) { Client.create(
    email: 'test@ex.com',
    first_name: 'test', last_name: 'ex', country: 'PK', phone: '03211223344')
  }

  before do
    sign_in client
  end

  # describe "GET #index" do
  #   it "returns http success" do
  #     get :index
  #     expect(response).to have_http_status(:success)
  #   end
  # end

end
