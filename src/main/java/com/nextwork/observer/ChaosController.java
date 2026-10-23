package com.nextwork.observer;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class ChaosController {

    @GetMapping("/slow")
    public String slow(@RequestParam(defaultValue = "500") long ms) throws InterruptedException {
        Thread.sleep(Math.min(ms, 10000));
        return "slept " + ms + "ms\n";
    }

    @GetMapping("/error")
    public String error() {
        throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "simulated failure");
    }

    @GetMapping("/simulate-cpu")
public String cpuEndpoint() {
    long endTime = System.currentTimeMillis() + 10000;
    while (System.currentTimeMillis() < endTime) {
        // Infinite loop for 10 seconds to burn CPU
    }
    return "CPU Burned";
}

}






















