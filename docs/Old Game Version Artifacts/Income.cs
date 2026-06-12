using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using TMPro;

public class Income : MonoBehaviour
{
    private float balance = 0f;
    private float nextScoreUpdateTime;
    
    private Income() {
        balance = 0;
    }

    public void CollectIncome(float amount) {
        balance += amount;
        EventManager.RaiseOnBalanceChanged(balance);
    }

    public void Spend(float amount) {
        balance -= amount;
        EventManager.RaiseOnBalanceChanged(balance);
    }

    private void Awake() {
        EventManager.onIncomeCollected += CollectIncome;
    }

    private void Start() {
        // EventManager.RaiseOnBalanceChanged(balance);
        // nextScoreUpdateTime = Time.time + scoreUpdateDelay;
    }

    // private void Update() {
    //     if (Time.time >= nextScoreUpdateTime) {
    //         EventManager.RaiseOnBalanceChanged(balance);
    //         nextScoreUpdateTime = Time.time + scoreUpdateDelay;
    //     }
    // }

    public float GetBalance() {
        return balance;
    }

    public void TogglePurchaseMultiplier() {

    }
}
