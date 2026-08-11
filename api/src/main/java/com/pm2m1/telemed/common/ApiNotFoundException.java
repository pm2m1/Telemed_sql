package com.pm2m1.telemed.common;

public class ApiNotFoundException extends RuntimeException {

    private final String code;

    public ApiNotFoundException(String code, String message) {
        super(message);
        this.code = code;
    }

    public String code() {
        return code;
    }
}
