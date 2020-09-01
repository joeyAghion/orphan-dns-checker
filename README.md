Compares EC2, ELB ("classic" and v2), and Cloudfront data to Cloudflare DNS data in order to identify DNS records that might be orphaned (and vulnerable to subdomain squatting). Does _not_ currently handle S3, Heroku, or other legitimate types of external DNS references.

Set up:

    bundle

To run:

    CLOUDFLARE_TOKEN=*** CLOUDFLARE_ZONE=artsy.net AWS_ACCESS_KEY_ID=*** AWS_SECRET_ACCESS_KEY=*** bundle exec ruby script.rb

Example output:

    Unrecognized A records: 
    {
      "foo.artsy.net": "54.84.92.471"
    }
    Unrecognized CNAME records:
    {
      "bar.artsy.net": "bar.s3-website-us-east-1.amazonaws.com",
      "baz.artsy.net": "baz.artsy.net.herokudns.com"
    }

&copy; 2020 Artsy
