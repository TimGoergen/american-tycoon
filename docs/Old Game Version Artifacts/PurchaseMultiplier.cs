using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using TMPro;
using System;

public class PurchaseMultiplier : MonoBehaviour
{
    [SerializeField] TextMeshProUGUI purchaseMultiplierDisplay;
    private List<int> purchaseMultipliers;
    private int purchaseMultiplierIndex;

    void Start() {
        SetPurchaseMultipliers();
    }

    private void SetPurchaseMultipliers() {
        purchaseMultipliers = new List<int> {0,1,10,100};
        purchaseMultiplierIndex = 1;
        SetPurchaseMultiplierText();
    }

    private void SetPurchaseMultiplierText() {
        string multiplierText;
        switch (purchaseMultiplierIndex) {
            case 0: {
                multiplierText = "MAX";
                break;
            }
            default: {
                multiplierText = "+" + purchaseMultipliers[purchaseMultiplierIndex].ToString();
                break;
            }
        }
        purchaseMultiplierDisplay.text = multiplierText;
    }

    public void OnPurchaseMultiplierButtonClick() {
        IncrementPurchaseMultiplier();
    }

    private void IncrementPurchaseMultiplier() {
        if (purchaseMultiplierIndex >= purchaseMultipliers.Count-1) {
            purchaseMultiplierIndex = 0;
        }
        else {
            purchaseMultiplierIndex++;
        }
        SetPurchaseMultiplierText();
        EventManager.RaiseOnPurchaseMultiplierChanged(purchaseMultipliers[purchaseMultiplierIndex]);
    }
}
