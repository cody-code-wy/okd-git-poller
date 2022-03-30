FROM codycode/okd-tools:4.10.0
RUN apk --no-cache add zsh jq git
COPY check_all.sh .
RUN chmod +x check_all.sh
CMD ./check_all.sh
