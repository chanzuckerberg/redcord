mkdir -p ~/.gem
touch ~/.gem/credentials
chmod 600 ~/.gem/credentials
echo "---" >> ~/.gem/credentials
echo ":github: Bearer ${GITHUB_TOKEN}" >> ~/.gem/credentials
echo ":rubygems_api_key: ${RUBYGEMS_API_KEY}" >> ~/.gem/credentials
gem build *.gemspec
gem push *.gem
