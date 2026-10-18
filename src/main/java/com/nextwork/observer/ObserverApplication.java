package com.nextwork.observer;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@SpringBootApplication
public class ObserverApplication {

    @GetMapping("/")
    public String home() {
        return "observer-service: ok\n";
    }

    public static void main(String[] args) {
        SpringApplication.run(ObserverApplication.class, args);
    }
}
