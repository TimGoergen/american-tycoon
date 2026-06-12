using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;

public class EventManager : MonoBehaviour
{
    // income balance has changed, usually on set schedule
    public delegate void OnBalanceChanged(float score);
    public static event OnBalanceChanged onBalanceChanged;
    public static void RaiseOnBalanceChanged(float score) {
        if (onBalanceChanged != null) {
            onBalanceChanged(score);
        }
    }

    // income has been collected, on a given income cycle
    public delegate void OnIncomeCollected(float amount);
    public static event OnIncomeCollected onIncomeCollected;
    public static void RaiseOnIncomeCollected(float amount) {
        if (onIncomeCollected != null) {
            onIncomeCollected(amount);
        }
    }

    // purchase multiplier has changed
    public delegate void OnPurchaseMultiplierChanged(int purchaseMultiplier);
    public static event OnPurchaseMultiplierChanged onPurchaseMultiplierChanged;
    public static void RaiseOnPurchaseMultiplierChanged(int purchaseMultiplier) {
        if (onPurchaseMultiplierChanged != null) {
            onPurchaseMultiplierChanged(purchaseMultiplier);
        }
    }


}
