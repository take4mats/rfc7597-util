# Monkey-patch for original IPAddress::IPv6 class to achieve 'aggregate' or '+'
module IPAddress
  require 'ipaddress'

  #
  # Parse the argument string to create a new
  # IPv4, IPv6 or Mapped IP object
  #
  #   ip  = IPAddress.parse 167837953 # 10.1.1.1
  #   ip  = IPAddress.parse "172.16.10.1/24"
  #   ip6 = IPAddress.parse "2001:db8::8:800:200c:417a/64"
  #   ip_mapped = IPAddress.parse "::ffff:172.16.10.1/128"
  #
  # All the object created will be instances of the
  # correct class:
  #
  #  ip.class
  #    #=> IPAddress::IPv4
  #  ip6.class
  #    #=> IPAddress::IPv6
  #  ip_mapped.class
  #    #=> IPAddress::IPv6::Mapped
  #
  def self.parse(str)
    # Check if an int was passed
    return IPAddress::IPv4.new(ntoa(str)) if str.is_a? Integer

    case str
    when /:.+\./
      IPAddress::IPv6::Mapped.new(str)
    when /\./
      IPAddress::ExtIPv4.new(str)
    when /:/
      IPAddress::ExtIPv6.new(str)
    else
      raise ArgumentError, "Unknown IP Address #{str}"
    end
  end

  #
  # summarize either IPv4 or IPv6 string array
  # Example:
  #   ip_strings = ['10.0.0.0/9', '192.168.0.0/16', '10.128.0.0/9']
  #   IPAddress.summarize(ip_strings)
  #   # => ['10.0.0.0/8', '192.168.0.0/16']
  #
  def self.summarize(ip_strings)
    ip_objects = ip_strings.map { |ip_string| IPAddress(ip_string) }

    if ip_objects[0].ipv4?
      return IPAddress::ExtIPv4.summarize(*ip_objects).map(&:to_string)
    elsif ip_objects[0].ipv6?
      return IPAddress::ExtIPv6.summarize(*ip_objects).map(&:to_string)
    else
      raise ArgumentError, "Unknown IP Address #{ip_objects[0]}"
    end
  end

  #
  # Example:
  #   ip_strings = ['10.0.0.0/8', '192.168.0.0/16']
  #   IPAddress.exclusive?(ip_strings)
  #   # => true
  #
  def self.exclusive?(ip_strings)
    ip_objects = ip_strings.map { |ip_string| IPAddress(ip_string) }

    ip_objects.each_with_index do |ip, index1|
      a = Marshal.load(Marshal.dump(ip_objects))
      a.delete_at(index1)
      a.each_with_index do |oth4, i|
        next unless ip.include?(oth4)
        index2 = i < index1 ? i : i + 1
        # puts "Inclusive entities found: #{ip.to_string} at #{index1} and #{oth4.to_string} at #{index2}"
        return false
      end
    end
    return true
  end

  # Monkey-patched IPv4 class to add original utility
  class ExtIPv4 < IPv4
    #
    # Returns the total number of IP addresses included
    # in multiple networks.
    #
    #   ip1 = IPAddress("10.0.0.1/29")
    #   ip2 = IPAddress("192.168.0.1/29")
    #
    #   IPAddress::ExtIPv4::size([ip1, ip2])
    #     #=> 16
    #
    def self.size_all(prefixes)
      result = 0
      prefixes.each do |ip|
        result += IPAddress(ip).size
      end
      return result
    end
  end

  # Monkey-patched IPv4 class to add original utility
  class ExtIPv6 < IPv6
    #
    # Returns the total number of IP addresses included
    # in multiple networks.
    #
    #   ip1 = IPAddress("10.0.0.1/29")
    #   ip2 = IPAddress("192.168.0.1/29")
    #
    #   IPAddress::ExtIPv4::size([ip1, ip2])
    #     #=> 16
    #
    def self.size_all(prefixes)
      result = 0
      prefixes.each do |ip|
        result += IPAddress(ip).size
      end
      return result
    end

    #
    # Checks whether a subnet includes all the
    # given IPv4 objects.
    #
    #   ip = IPAddress("192.168.10.100/24")
    #
    #   addr1 = IPAddress("192.168.10.102/24")
    #   addr2 = IPAddress("192.168.10.103/24")
    #
    #   ip.(addr1,addr2)
    #     #=> true
    #
    def include_all?(*others)
      others.all? { |oth| include?(oth) }
    end

    #
    # Returns a new IPv4 object from the supernetting
    # of the instance network.
    #
    # Supernetting is similar to subnetting, except
    # that you getting as a result a network with a
    # smaller prefix (bigger host space). For example,
    # given the network
    #
    #   ip = IPAddress("172.16.10.0/24")
    #
    # you can supernet it with a new /23 prefix
    #
    #   ip.supernet(23).to_string
    #     #=> "172.16.10.0/23"
    #
    # However if you supernet it with a /22 prefix, the
    # network address will change:
    #
    #   ip.supernet(22).to_string
    #     #=> "172.16.8.0/22"
    #
    # If +new_prefix+ is less than 1, returns 0.0.0.0/0
    #
    def supernet(new_prefix)
      if new_prefix >= @prefix.to_i
        raise ArgumentError, 'New prefix must be smaller than existing prefix'
      end
      return self.class.new('::/0') if new_prefix < 1
      return self.class.new(@address + "/#{new_prefix}").network
    end

    #
    # Returns a new IPv4 object which is the result
    # of the summarization, if possible, of the two
    # objects
    #
    # Example:
    #
    #   ip1 = IPAddress("172.16.10.1/24")
    #   ip2 = IPAddress("172.16.11.2/24")
    #
    #   p (ip1 + ip2).map {|i| i.to_string}
    #     #=> ["172.16.10.0/23"]
    #
    # If the networks are not contiguous, returns
    # the two network numbers from the objects
    #
    #   ip1 = IPAddress("10.0.0.1/24")
    #   ip2 = IPAddress("10.0.2.1/24")
    #
    #   p (ip1 + ip2).map {|i| i.to_string}
    #     #=> ["10.0.0.0/24","10.0.2.0/24"]
    #
    def +(other)
      aggregate(*[self, other].sort.map{ |i| i.network })
    end

    #
    # Summarization (or aggregation) is the process when two or more
    # networks are taken together to check if a supernet, including all
    # and only these networks, exists. If it exists then this supernet
    # is called the summarized (or aggregated) network.
    #
    # It is very important to understand that summarization can only
    # occur if there are no holes in the aggregated network, or, in other
    # words, if the given networks fill completely the address space
    # of the supernet. So the two rules are:
    #
    # 1) The aggregate network must contain +all+ the IP addresses of the
    #    original networks;
    # 2) The aggregate network must contain +only+ the IP addresses of the
    #    original networks;
    #
    # A few examples will help clarify the above. Let's consider for
    # instance the following two networks:
    #
    #   ip1 = IPAddress("172.16.10.0/24")
    #   ip2 = IPAddress("172.16.11.0/24")
    #
    # These two networks can be expressed using only one IP address
    # network if we change the prefix. Let Ruby do the work:
    #
    #   IPAddress::IPv4::summarize(ip1,ip2).to_s
    #     #=> "172.16.10.0/23"
    #
    # We note how the network "172.16.10.0/23" includes all the addresses
    # specified in the above networks, and (more important) includes
    # ONLY those addresses.
    #
    # If we summarized +ip1+ and +ip2+ with the following network:
    #
    #   "172.16.0.0/16"
    #
    # we would have satisfied rule #1 above, but not rule #2. So "172.16.0.0/16"
    # is not an aggregate network for +ip1+ and +ip2+.
    #
    # If it's not possible to compute a single aggregated network for all the
    # original networks, the method returns an array with all the aggregate
    # networks found. For example, the following four networks can be
    # aggregated in a single /22:
    #
    #   ip1 = IPAddress("10.0.0.1/24")
    #   ip2 = IPAddress("10.0.1.1/24")
    #   ip3 = IPAddress("10.0.2.1/24")
    #   ip4 = IPAddress("10.0.3.1/24")
    #
    #   IPAddress::IPv4::summarize(ip1,ip2,ip3,ip4).to_string
    #     #=> "10.0.0.0/22",
    #
    # But the following networks can't be summarized in a single network:
    #
    #   ip1 = IPAddress("10.0.1.1/24")
    #   ip2 = IPAddress("10.0.2.1/24")
    #   ip3 = IPAddress("10.0.3.1/24")
    #   ip4 = IPAddress("10.0.4.1/24")
    #
    #   IPAddress::IPv4::summarize(ip1,ip2,ip3,ip4).map{|i| i.to_string}
    #     #=> ["10.0.1.0/24","10.0.2.0/23","10.0.4.0/24"]
    #
    def self.summarize(*args)
      # one network? no need to summarize
      return [args.first.network] if args.size == 1

      i = 0
      result = args.dup.sort.map{ |ip| ip.network }
      while i < result.size - 1
        sum = result[i] + result[i + 1]
        result[i..i + 1] = sum.first if sum.size == 1
        i += 1
      end

      result.flatten!
      if result.size == args.size
        # nothing more to summarize
        return result
      else
        # keep on summarizing
        return summarize(*result)
      end
    end

    #
    # private methods
    #
    private

    def aggregate(ip1,ip2)
      return [ip1] if ip1.include? ip2

      snet = ip1.supernet(ip1.prefix - 1)
      if snet.include_all?(ip1, ip2) && ((ip1.size + ip2.size) == snet.size)
        return [snet]
      else
        return [ip1, ip2]
      end
    end
  end
end
