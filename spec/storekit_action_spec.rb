describe Fastlane::Actions::StorekitAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The storekit plugin is working!")

      Fastlane::Actions::StorekitAction.run(nil)
    end
  end
end
