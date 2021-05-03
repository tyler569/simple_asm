#!/usr/bin/env ruby
require 'optparse'

$options = {
  mode: 'simple'
}

OptionParser.new do |opts|
  opts.on('-f', '--file FILE', 'ASM file to assemble') { |f| $options[:file] = f }
  opts.on('-t', '--test', 'Self test') { $options[:test] = true }
  opts.on('-d', '--debug', 'Debug!') { $options[:debug] = 0 }
  opts.on('-m', '--mode MODE', 'Select a mode') { |v| $options[:mode] = v }
end.parse!

class Instruction
  attr_reader :format, :encoding, :mnemonic, :format_parts
  attr_reader :internal_format

  class SimpleArg
    attr_reader :spec, :type, :n

    def SimpleArg.from_part(part)
      return part[1..] if part.start_with? '$'
      return nil unless part =~ /\A(\w)(\d)\z/
      return nil unless ARG_TYPES.include? $1
      SimpleArg.new(part)
    end

    def initialize(spec)
      return nil unless spec =~ /\A(\w)(\d)\z/
      return nil unless ARG_TYPES.include? $1
      @spec = spec
      @type = ARG_TYPES[$1]
      @n = $2.to_i
    end

    def to_s
      "Arg(#{type}, #{n})"
    end

    private def render(number, bits)
      (number & (2**bits-1)).to_s(2).rjust(bits, '0')
    end

    ARG_TYPES = {
      'p' => :page,
      'R' => :register,
      'i' => :immediate4,
      'I' => :immediate8,
      'J' => :immediate16,
      'j' => :jumpcond,
      'g' => :oneop,
      'h' => :twoop,
      'L' => :label
    }

    JUMP_CONDS = {
      'ja'  => 1,  'jnbe' => 1,
      'jae' => 2,  'jnb' => 2,  'jnc' => 2,
      'jb'  => 3,  'jnae' => 3, 'jc' => 3,
      'jbe' => 4,  'jna' => 4,
      'jg'  => 5,  'jnle' => 5,
      'jge' => 6,  'jnl' => 6,
      'jl'  => 7,  'jnge' => 7,
      'jle' => 8,  'jng' => 8,
      'jeq' => 9,  'je' => 9,   'jz' => 9,
      'jne' => 10, 'jnz' => 10,
      'jo'  => 11,
      'jno' => 12,
      'jmp' => 13,
    }

    ONE_OPS = {
      'not'  => 1,
      'inv'  => 2,
      'push' => 3,
      'pop'  => 4,
      'inc'  => 5,
      'dec'  => 6,
    }

    TWO_OPS = {
      'add'  => 1,
      'sub'  => 2,
      'or'   => 3,
      'nor'  => 4,
      'and'  => 5,
      'nand' => 6,
      'xor'  => 7,
      'xnor' => 8,
      'adc'  => 9,
      'sbb'  => 10,
      'cmp'  => 11,
    }

    def match?(text)
      case type
      when :page
        text =~ /\Ap(\d+)\z/ && $1.to_i.between?(0, 3)
      when :register
        text =~ /\Ar(\d+)\z/ && $1.to_i.between?(0, 15)
      when :immediate4
        Integer(text).between?(0, 15)
      when :immediate8
        Integer(text).between?(-128, 255)
      when :immediate16
        Integer(text).between?(-2**15, 2**16-1)
      when :label
        true
      when :jumpcond
        JUMP_CONDS.include? text
      when :oneop
        ONE_OPS.include? text
      when :twoop
        TWO_OPS.include? text
      end
    rescue ArgumentError
      nil
    end

    def bits(text)
      case type
      when :page
        render(text[1..].to_i, 2)
      when :register
        render(text[1..].to_i, 4)
      when :immediate4
        render(text.to_i, 4)
      when :immediate8
        render(text.to_i, 8)
      when :immediate16
        o = render(text.to_i, 16)
        [o[0..8], o[8..16]]
      when :label
        ":#{text[..-1]}"
      when :jumpcond
        render(JUMP_CONDS[text], 4)
      when :oneop
        render(ONE_OPS[text], 4)
      when :twoop
        render(TWO_OPS[text], 4)
      end
    end
  end

  class CapoArg
    attr_reader :spec, :type, :n

    def CapoArg.from_part(part)
      return part[1..] if part.start_with? '$'
      return nil unless part =~ /\A(\w)(\d)\z/
      return nil unless ARG_TYPES.include? $1
      CapoArg.new(part)
    end

    def initialize(spec)
      return nil unless spec =~ /\A(\w)(\d)\z/
      return nil unless ARG_TYPES.include? $1
      @spec = spec
      @type = ARG_TYPES[$1]
      @n = $2.to_i
    end

    def to_s
      "Arg(#{type}, #{n})"
    end

    private def render(number, bits)
      (number & (2**bits-1)).to_s(2).rjust(bits, '0')
    end

    ARG_TYPES = {
      'A' => :accumulator,
      'c' => :register1,
      'r' => :register2,
      'R' => :register3,
      'n' => :number,
    }

    def match?(text)
      case type
      when :accumulator
        text == "acc"
      when :register1
        text =~ /\Ar(\d+)\z/ && $1.to_i.between?(5, 6)
      when :register2
        text =~ /\Ar(\d+)\z/ && $1.to_i.between?(4, 7)
      when :register3
        text =~ /\Ar(\d+)\z/ && $1.to_i.between?(0, 7)
      when :number
        Integer(text).between?(-64, 127)
      end
    rescue ArgumentError
      nil
    end

    def bits(text)
      case type
      when :accumulator
        "Error - accumulator cannot be in bit representation"
      when :register1
        render(text.to_i - 5, 1)
      when :register2
        render(text.to_i - 4, 2)
      when :register3
        render(text.to_i, 3)
      when :number
        render(text.to_i, 7)
      end
    end
  end

  case $options[:mode]
  when 'simple'
    Arg = SimpleArg
  when 'capo'
    Arg = CapoArg
  end

  private def scan(text)
    text.scan(/\$?\w+|\S/)
  end

  def initialize(s)
    @format, @encoding = s.split(';').map(&:strip)
    @mnemonic = format.split.first
    @format_parts = scan format

    @internal_format = format_parts.map { |p| Arg.from_part(p) || p }
    @internal_encoding = encoding.split('+').map(&:strip)
  end

  def encode(text)
    puts "--- #{self}" if $options[:debug] > 1
    tokens = scan text
    return nil unless tokens.length == format_parts.length
    values = {'%' => tokens[0]}
    internal_format.zip(tokens).each do |f, t|
      puts "#{f} / #{t}" if $options[:debug] > 1
      case f
      when String
        return nil unless f == t
      when Arg
        return nil unless f.match? t
        values[f.spec] = f.bits t
      end
    end
    puts "#{text} : #{self} : #{values}" if $options[:debug]

    @internal_encoding.flat_map do |e|
      case
      when e.start_with?('#')
        out = e[1..]
        values.each do |k, v|
          next unless v.is_a? String
          out.sub!(k, v)
        end
        out
      when e.start_with?('@')
        values[e[1..]]
      else
        # TODO
      end
    end
  end

  def to_s
    "Instruction(#{format}; #{encoding})"
  end
end

def output(arr)
  arr.map { |i| i.to_s(2).rjust(8, '0') }
end

def check(example, correct)
  if actual != correct
    puts "#{example} is wrong!"
    puts "  matched: #{instr}"
    puts "  got:     #{output actual}"
    puts "  wanted:  #{output correct}"
  else
    puts "#{example.ljust(20)} #{output(actual).inspect.ljust(40)} ✓"
  end
end

$all = []

file = case $options[:mode]
       when 'simple'
         'simple16'
       when 'capo'
         'capo'
       end

File.read(file).lines do |line|
  next if line.strip.empty?
  next if line.strip.start_with? '#'

  i = Instruction.new(line)
  $all << i
  puts "#{i}   #{i.internal_format.map(&:to_s)}" if $options[:debug]
end

if $options[:test]
end

def is_label?(line)
  line.end_with? ':'
end

def label(line)
  "label:#{line[..-2]}"
end

def encode(i, line)
  if is_label? line
    label line
  else
    encoded = nil
    $all.find { |i| encoded = i.encode(line) }
    if encoded.nil?
      STDERR.puts "#{line} (line #{i+1}) does not match any instruction or encoding"
      exit 1
    end
    encoded
  end
end

if $options[:file]
  puts File.read($options[:file])
      .lines
      .each_with_index
      .map { |line, i| [line.strip, i] }
      .reject { |line, i| line.empty? }
      .flat_map { |line, i| encode i, line }
else
  require 'readline'
  while buf = Readline.readline('> ', true)
    $all.find { |i| x = i.encode(buf); p x if x }
  end
end
