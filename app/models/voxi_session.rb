# Eventually we should use this to store data of IVR instead of using rails session
class VoxiSession < ApplicationRecord
  belongs_to :client
  belongs_to :ivr
  belongs_to :call, optional: true

  serialize :data, Hash
end
