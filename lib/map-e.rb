# this is the class
class MapE
  # require './lib/myipaddress'
  require 'ipaddress'

  IPV6_BIT_LEN = 128
  IPV4_BIT_LEN = 32
  PORT_BIT_LEN = 16

  attr_accessor :rule_net6,
                :rule_net4,
                :ea_bit_len,
                :psid_offset,
                :br_addr6,
                :is_rfc,
                :pref6_len,
                :pref4_len,
                :suffix6_len,
                :suffix4_len,
                :user_pref6_len,
                :subnet_id_len,
                :if_id_pad_head_len,
                :if_id_pad_tail_len,
                :psid_len,
                :free_port_bit_len,
                :rsv_port,
                :density4,
                :ports_per_user,
                :total_user

  def initialize(provider_params)
    @rule_net6 = provider_params[:rule_net6] # '2001:db8::/30'
    @rule_net4 = provider_params[:rule_net4] # '198.32.0.0/12'
    @ea_bit_len = provider_params[:ea_bit_len]
    @psid_offset = provider_params[:psid_offset]
    @br_addr6 = provider_params[:br_addr6]
    @is_rfc = provider_params[:is_rfc]


    @pref6_len = IPAddress(@rule_net6).prefix.to_i
    @pref4_len = IPAddress(@rule_net4).prefix.to_i
    @suffix6_len = IPV6_BIT_LEN - @pref6_len
    @suffix4_len = IPV4_BIT_LEN - @pref4_len

    @user_pref6_len = @pref6_len + @ea_bit_len
    @subnet_id_len = 64 - @user_pref6_len
    @if_id_pad_head_len = is_rfc ? 16 : 8
    @if_id_pad_tail_len = is_rfc ? 0 : 8
    @psid_len = @ea_bit_len - @suffix4_len
    @free_port_bit_len = PORT_BIT_LEN - (@psid_offset + @psid_len)
    @rsv_port = 2**(PORT_BIT_LEN - @psid_offset)
    @density4 = 2**@psid_len
    @ports_per_user = (2**PORT_BIT_LEN - @rsv_port) / @density4
    @total_user = 2**(@suffix4_len + @psid_len)
  end

  # provides mapping info in detail, from BMR
  def mapping_info(pref6_obj)
    pref4_bits = IPAddress(@rule_net4).bits[0, @pref4_len]
    suffix4_bits = pref6_obj.bits[@pref6_len, @suffix4_len]
    addr4_obj = IPAddress::IPv4.parse_u32((pref4_bits + suffix4_bits).to_i(2))
    psid = pref6_obj.bits[@pref6_len + @suffix4_len, @psid_len].to_i(2)

    response = {
      pref6: pref6_obj.to_string,
      addr4: addr4_obj.to_s,
      psid: psid,
      port_range: psid_to_port_range(psid),
      ports: psid_to_ports(psid)
    }

    return response
  end

  def ipv4_to_ipv6(ipv4)
    addr4 = ipv4[:ipv4_address]
    psid = ipv4[:psid]
    rule_net4_obj = IPAddress(@rule_net4)
    unless rule_net4_obj.include?(IPAddress(addr4))
      raise ArgumentError.new("Invalid request!  The given address #{addr4} is not included in #{@rule_net4}.")
    end

    bits = IPAddress(@rule_net6).bits
    pref6_bits = bits[0, @pref6_len]

    addr4_bits = IPAddress(addr4).bits
    suffix4_bits = addr4_bits[-@suffix4_len, @suffix4_len]
    psid_bits = psid.to_s(2).rjust(@psid_len, '0')
    ea_bits = suffix4_bits + psid_bits

    subnet_id_bits = '0' * @subnet_id_len

    padded_psid_bits = psid_bits.rjust(PORT_BIT_LEN, '0')
    if_id_bits = '0' * @if_id_pad_head_len + addr4_bits + padded_psid_bits + '0' * @if_id_pad_tail_len

    map_ce_addr6_bits = pref6_bits + ea_bits + subnet_id_bits + if_id_bits
    map_ce_addr6 = IPAddress::IPv6.parse_u128(map_ce_addr6_bits.to_i(2)).to_s
    addr6_bits = pref6_bits + ea_bits + subnet_id_bits + '0' * 64
    addr6 = IPAddress::IPv6.parse_u128(addr6_bits.to_i(2)).to_s
    return { ipv6_address: addr6, map_ce_ipv6_address: map_ce_addr6 }
  end

  def ipv6_to_ipv4(addr6)
    rule_net6_obj = IPAddress(@rule_net6)
    unless rule_net6_obj.include?(IPAddress(addr6))
      raise ArgumentError.new("Invalid request!  The given address #{addr6} is not included in #{@rule_net6}.")
    end

    addr6_bits = IPAddress(addr6).bits

    suffix4_bits_head_position = @pref6_len
    suffix4_bits = addr6_bits[suffix4_bits_head_position, @suffix4_len]
    pref4_bits = IPAddress(@rule_net4).bits[0, @pref4_len]
    addr4_bits = pref4_bits + suffix4_bits
    addr4 = IPAddress::IPv4.parse_u32(addr4_bits.to_i(2))

    psid_bits_head_position = @pref6_len + @suffix4_len
    psid_bits = addr6_bits[psid_bits_head_position, @psid_len]
    psid = psid_bits.to_i(2)

    # TODO: bit表現も return?
    return { ipv4_address: addr4.to_s, psid: psid }
  end

  def psid_to_port_range(psid)
    exit if @psid_offset <= 0

    arr1 = []
    shift1 = 16 - @psid_offset
    shift2 = @free_port_bit_len

    (1..(2**@psid_offset - 1)).each do |i|
      prt = i * 2**shift1 + psid * 2**shift2
      ports = (prt + 0)..(prt + 2**@free_port_bit_len - 1)
      arr1 << ports
    end

    return arr1
  end

  def psid_to_ports(psid)
    exit if @psid_offset <= 0

    arr1 = []
    shift1 = @free_port_bit_len + @psid_len
    shift2 = @free_port_bit_len

    (1..(2**@psid_offset - 1)).each do |i|
      (0..(2**@free_port_bit_len - 1)).each do |j|
        port = i * 2**shift1 + psid * 2**shift2 + j
        arr1 << port
      end
    end

    return arr1
  end

  def port_reserved?(port)
    return false if port >= @rsv_port
    return false if port < 0
    return true
  end

  def port_to_psid(port)
    mask_dec = ('0' * @psid_offset + '1' * @psid_len + '0' * @free_port_bit_len).to_i(2)
    matched = port & mask_dec
    psid = matched / (2**@free_port_bit_len)
    return psid
  end
end
