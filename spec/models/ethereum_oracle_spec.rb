describe EthereumOracle, type: :model do
  describe "validations" do
    it { is_expected.to have_valid(:endpoint).when('https://bitstamp.net/api/ticker/', 'http://example.net/api?foo=bar|baz') }
    it { is_expected.not_to have_valid(:endpoint).when(nil, '', 'ftp://bitstamp.net/api/ticker/', 'http://example.net/api ?foo=bar|baz') }

    it { is_expected.to have_valid(:ethereum_contract).when(EthereumContract.new) }
    it { is_expected.not_to have_valid(:ethereum_contract).when(nil) }

    it { is_expected.to have_valid(:fields).when('recent', ['recent', 'high']) }
    it { is_expected.not_to have_valid(:fields).when(nil, '', []) }
  end

  describe "#current_value" do
    let(:oracle) { EthereumOracle.new }
    let(:response_body) { {a: 1}.to_json }
    let(:rando) { SecureRandom.hex }

    it "reaches out to the web and parses the json" do
      expect(HttpRetriever).to receive(:get)
        .with(oracle.endpoint)
        .and_return(response_body)

      expect(JsonTraverser).to receive(:parse)
        .with(response_body, oracle.fields)
        .and_return(rando)

      expect(oracle.current_value).to eq(rando)
    end
  end

  describe "#fields" do
    let(:oracle) { EthereumOracle.new fields: fields }

    context "when it is set to be a single string" do
      let(:fields) { 'singleValue' }

      it "sets the list to be an array" do
        expect(oracle.fields).to eq([fields])
      end
    end

    context "when it is set to be an array" do
      let(:fields) { ['multiple', 'values'] }

      it "uses the initial array" do
        expect(oracle.fields).to eq(fields)
      end
    end
  end

  describe "#ready?" do
    subject { factory_build(:ethereum_oracle, ethereum_contract: contract).ready? }

    context "when the contract has an address" do
      let(:contract) { factory_build :ethereum_contract, address: ethereum_address }
      it { is_expected.to be true }
    end

    context "when the contract does not have an address" do
      let(:contract) { factory_build :ethereum_contract, address: nil }
      it { is_expected.to be false }
    end
  end

  describe "#contract_confirmed" do
    let(:subtask) { factory_build :subtask, adapter: nil }
    let(:oracle) { factory_create :ethereum_oracle, subtask: subtask }

    it "calls mark ready on the subtask" do
      expect(subtask).to receive(:mark_ready)

      oracle.contract_confirmed(ethereum_address)
    end
  end

  describe "#initialization_details" do
    let(:contract) { factory_create :ethereum_contract, address: ethereum_address }
      let(:oracle) do
        factory_create(:ethereum_oracle).tap do |oracle|
          oracle.update_attributes(ethereum_contract: contract)
        end
      end

    it "pulls information from the ethereum contract and template" do
      expect(oracle.initialization_details).to eq({
        address: contract.address,
        jsonABI: contract.template.json_abi,
        readAddress: contract.template.read_address,
        writeAddress: contract.template.write_address,
        solidityABI: contract.template.solidity_abi,
      })
    end
  end
end
