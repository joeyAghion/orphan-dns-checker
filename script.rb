Bundler.require(:default)

config = Hash[
  [
    'CLOUDFLARE_TOKEN',
    'CLOUDFLARE_ZONE',
    'AWS_ACCESS_KEY_ID',
    'AWS_SECRET_ACCESS_KEY'
  ].map { |key| [key, ENV[key]] }
]
raise "Configuration for all of #{config.keys.join(', ')} is required" if config.values.any?(&:nil?)

AWS_REGION = 'us-east-1'

dns = []
Cloudflare.connect(token: config['CLOUDFLARE_TOKEN']) do |cf|
  zone = cf.zones.find_by_name(config['CLOUDFLARE_ZONE'])
  zone.dns_records.each { |r| $stderr.print '.'; dns << r }
end
dns_names = dns.map(&:name).sort

aws_creds = Aws::Credentials.new(
  config['AWS_ACCESS_KEY_ID'],
  config['AWS_SECRET_ACCESS_KEY']
)
ec2 = Aws::EC2::Client.new(region: AWS_REGION, credentials: aws_creds)
instances = ec2.describe_instances(
  filters: [{ name: 'instance-state-name', values: ['running'] }]
).reservations.flat_map(&:instances)
public_ips = instances.map(&:public_ip_address)
private_ips = instances.map(&:private_ip_address)
instance_names = instances.map(&:public_dns_name)

# classic load balancers:
elb = Aws::ElasticLoadBalancing::Client.new(region: AWS_REGION, credentials: aws_creds)
elbs = elb.describe_load_balancers.flat_map(&:load_balancer_descriptions)
# application or network load balancers:
elb2 = Aws::ElasticLoadBalancingV2::Client.new(region: AWS_REGION, credentials: aws_creds)
elbs += elb2.describe_load_balancers.load_balancers
elb_names = elbs.map(&:dns_name)

# A records with target IPs not found in our EC2 instances:
unrecognized_a_records = Hash[
  dns.select { |r| r.type == 'A' }.
    reject { |r| public_ips.include?(r.content) }.
    map { |r| [r.name, r.content] }.
    sort
]

puts "\nUnrecognized A records:\n#{JSON.pretty_generate(unrecognized_a_records)}\n"

cloudfront = Aws::CloudFront::Client.new(region: AWS_REGION, credentials: aws_creds)
cf_domains = cloudfront.list_distributions.distribution_list.items.map(&:domain_name).sort

known_names = elb_names | cf_domains | dns_names | instance_names
# CNAME records with targets not found in our ELBs or other DNS entries
unrecognized_cname_records = Hash[
  dns.select { |r| r.type == 'CNAME' }.
    reject { |r| known_names.include?(r.content) }.
    map { |r| [r.name, r.content] }.
    sort
]

puts "Unrecognized CNAME records:\n#{JSON.pretty_generate(unrecognized_cname_records)}\n"
