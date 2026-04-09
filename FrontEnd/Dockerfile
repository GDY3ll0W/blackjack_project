FROM ghcr.io/cirruslabs/flutter:latest AS build

USER root
WORKDIR /app

COPY pubspec.yaml pubspec.lock ./

RUN flutter pub get --no-example

COPY . .

RUN flutter build web

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]