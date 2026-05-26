# Use official Tomcat 9 with Java 21 pre-installed
FROM tomcat:9.0.82-jdk21-temurin

# Set maintainer label (optional but good practice)
LABEL maintainer="your.email@example.com"

# Remove default ROOT app (optional, keeps container clean)
RUN rm -rf /usr/local/tomcat/webapps/ROOT

# Create a user for running the application
RUN useradd -m mbookmytrip-ms

# Copy your WAR file into the webapps directory
COPY ./target/mbookmytrip-ms*.jar /usr/local/tomcat/webapps/

# Expose the default Tomcat port
EXPOSE 8080

# Set the user to 'mbookmytrip-ms' for security
USER mbookmytrip

# Default command to run Tomcat
CMD ["catalina.sh", "run"]
