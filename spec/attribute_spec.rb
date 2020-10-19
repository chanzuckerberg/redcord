# frozen_string_literal: true

# typed: false

describe Redcord::Attribute do
  let!(:klass) do
    Class.new(T::Struct) do
      include Redcord::Base

      attribute :a, Integer
      attribute :b, T.nilable(Integer), index: true
    end
  end

  let!(:another_klass) do
    Class.new(T::Struct) do
      include Redcord::Base

      ttl 2.hour

      attribute :boolean, T::Boolean, index: true
      attribute :float, Float, index: true
      attribute :integer, Integer, index: true
      attribute :string, String, index: true
      attribute :symbol, Symbol, index: true
      attribute :time, Time, index: true
    end
  end

  it 'defines props' do
    instance = klass.new(a: 1)

    %i[a b].each do |attribute|
      expect(instance.methods.include?(attribute)).to be true
      expect(instance.methods.include?(:"#{attribute}=")).to be true
    end

    expect(instance.id).to be_nil
  end

  it 'adds attributes to the classes' do
    expect(
      klass.class_variable_get(:@@range_index_attributes),
    ).to eq(Set.new([:b]))

    expect(
      another_klass.class_variable_get(:@@index_attributes),
    ).to eq(Set.new(%i[boolean string symbol]))

    expect(
      another_klass.class_variable_get(:@@range_index_attributes),
    ).to eq(Set.new(%i[float integer time]))

    expect(
      another_klass.class_variable_get(:@@ttl),
    ).to eq(2.hour)
  end

  it 'validates shard_by attribute presence in custom index: order A' do
    expect {
      Class.new(T::Struct) do
        include Redcord::Base
        attribute :a, Integer
        attribute :b, Integer, index: true
        custom_index :main, [:a, :b]
        shard_by_attribute :b
      end
    # shard_by attribute 'b' must be placed first
    }.to raise_error(Redcord::CustomIndexInvalidDesign)
    expect {
      Class.new(T::Struct) do
        include Redcord::Base
        attribute :a, Integer
        attribute :b, Integer, index: true
        custom_index :main, [:b, :a]
        shard_by_attribute :b
      end
    }.to_not raise_error()
  end

  it 'validates shard_by attribute presence in custom index: order B' do
    expect {
      Class.new(T::Struct) do
        include Redcord::Base
        attribute :a, Integer
        attribute :b, Integer, index: true
        shard_by_attribute :b
        custom_index :main, [:a, :b]
      end
    # shard_by attribute 'b' must be placed first
    }.to raise_error(Redcord::CustomIndexInvalidDesign)
    expect {
      Class.new(T::Struct) do
        include Redcord::Base
        attribute :a, Integer
        attribute :b, Integer, index: true
        shard_by_attribute :b
        custom_index :main, [:b, :a]
      end
    }.to_not raise_error()
  end

  it 'validates custom index attributes have allowed type' do
    expect {
      Class.new(T::Struct) do
        include Redcord::Base
        attribute :a, String, index: true
        custom_index :main, [:a]
      end
    # Custom index doesn't support 'String' attributes.
    }.to raise_error(Redcord::WrongAttributeType)
  end
end
