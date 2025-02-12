%Asset value
%
%Created Aug 14 2024
%by Robert Fofrich Navarro
%
%Calculates corporate asset value and assigns values to power plant parent company
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
FUEL = 1;% sets fuel %1 COAL,2 GAS, 3 OIL, 4 Combined
clearvars -except ii; close all

TJ_to_BTu = 1/(9.478*1e8);
Kg_CO2_to_t_C02 = 1/1000;
BTu_perKWh_to_BTu_perMWh = 1000;

max_marker_size = 3000;
min_marker_size = 200; 


PowerPlantFuel = ["Coal", "Gas", "Oil"];
saveyear = 0;%saves decommission year; any other number loads decommission year
saveresults = 1;
randomsave = 1;%set to 1 to save MC randomization; zero value  loads MC randomization - section 11 only


if FUEL <4
    CombineFuelTypeResults = 0;
elseif FUEL >3
    CombineFuelTypeResults = 1;
end

current_year = 2024;
cutoffyear = 2035;%follows the index for carbontaxyear vector
CarbonPrice = 2000;%$/tCO2
CarbonTaxYear = current_year:2100;%sets the year for which the carbon tax is at its maximum

[ Dateindx] = find(CarbonTaxYear == cutoffyear);

StartYear = 1900;
EndYear = current_year;
Year = StartYear:EndYear;

RetailtoWholesaleConversionFactor = 1;%assumption

%Median PowerPlant Costs and Life from IPCC AR5 WGIII
%(https://www.ipcc.ch/site/assets/uploads/2018/02/ipcc_wg3_ar5_annex-iii.pdf)
%Power plant life
 
interest_rate_construction = .05; % interest rate over the construction loan (set as 5%)
DiscountRate = .1; %rate used by IEA 2020 report, 7% is in a highly regulated market, and 10% is in an environment with high risks

mean_Life_coal = 40;
Variable_OM_coal = 3.4;% $/MWh
Fixed_OM_coal = 23*1000;% $/MW
Construction_period_coal = 6; 
Capital_costs_coal = 2200*1000;% $/MW
Fuel_costs_coal = 4.1/3.6; % $/MWh
alpha_coal = DiscountRate/(1-(1+DiscountRate).^-mean_Life_coal);% percent
eta_coal = .39;% percent
Investment_costs_coal = (Capital_costs_coal/mean_Life_coal)*sum((1+interest_rate_construction)*(1+(0/(1+DiscountRate).^mean_Life_coal)));

mean_Life_gas = 30;
Variable_OM_gas = 3.2;% $/MWh
Fixed_OM_gas = 7*1000;% $/MW
Construction_period_gas = 4; 
Capital_costs_gas = 1100*1000;% $/MW
Fuel_costs_gas = 8.9*3.6; % $/MWh
alpha_gas = DiscountRate/(1-(1+DiscountRate).^-mean_Life_gas);% percent
eta_gas = .55;% percent
Investment_costs_gas = (Capital_costs_gas/mean_Life_gas)*sum((1+interest_rate_construction)*(1+(0/(1+DiscountRate).^mean_Life_gas)));

%Power plant ranges
LifeTimeRange = 20:5:60; 
CapacityFactorRange = .25:.05:.75;
AnnualHours = 8760;

%plus/minus age
Age_span = 20;% Power plant age range

%plus/minus CF
CF_span = .25;% Power plant capacity factor range
if FUEL == 1
    years = 2021:(current_year + mean_Life_coal);
elseif FUEL == 2
    years = 2021:(current_year + mean_Life_gas);
end

for gentype = FUEL
    if CombineFuelTypeResults ~= 1
        load(['../Data/Results/' PowerPlantFuel{gentype} '_Plants']);
        load(['../Data/Results/' PowerPlantFuel{gentype} '_Plants_strings']);      
        load(['../Data/Results/PowerPlantFinances_byCompany_' PowerPlantFuel{gentype} '']);
        Plants(:,2) = round(Plants(:,2));
        Plants(isnan(Plants)) = 0;
        Emission_factor(isnan(Emission_factor))=0;

        if gentype == 1
            LifeLeft = mean_Life_coal - Plants(:,2);
            mean_Life = mean_Life_coal;
            Heat_rate(isnan(Heat_rate))=0;
        elseif gentype == 2
            LifeLeft = mean_Life_gas - Plants(:,2);
            mean_Life = mean_Life_gas;
        end

        if saveyear == 1
            for generator = 1:length(Plants)
                if isnan(Planned_decommission(generator))
                    if LifeLeft(generator,1) <=0 
                        yearsleft = randi(5);
                        DecommissionYear(generator,1) = current_year + yearsleft;
                        LifeLeft(generator,1) = yearsleft;
                    elseif LifeLeft(generator,1) > 0
                        DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                        LifeLeft(generator,1) = LifeLeft(generator,1);
                    end
                elseif ~isnan(Planned_decommission(generator))
                       LifeLeft(generator,1) = Planned_decommission(generator) - current_year;

                    if LifeLeft(generator,1) <=0 
                        yearsleft = randi(5);
                        DecommissionYear(generator,1) = current_year + yearsleft;
                        LifeLeft(generator,1) = yearsleft;

                    elseif LifeLeft(generator,1) > 0
                        DecommissionYear(generator,1) = current_year + LifeLeft(generator,1);
                        LifeLeft(generator,1) = LifeLeft(generator,1);
                    end
                end
            end
            DecommissionYear(28522:28525) = 0; % not iterating through the final power plants due to nans, these are decomissioned anyways
            save(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''],'DecommissionYear','LifeLeft');
        elseif saveyear ~=1
            load(['../Data/Results/DecommissionYear' PowerPlantFuel{gentype} ''])
        end


        LifeLeft(isnan(LifeLeft))=0;


        CompanyNames = unique(Plants_string(:,1));
        CountryNames = unique(Plants_string(:,2));
        if FUEL == 1
            AnnualEmissionsByCompany = zeros(length(CompanyNames),mean_Life+10);
            AnnualEmissionsByCountry = zeros(length(CountryNames),mean_Life+10);

            AnnualCapacityByCompany = zeros(length(CompanyNames),mean_Life+10);
            AnnualStrandedAssetByCompany19_globalpricing = zeros(length(CompanyNames),mean_Life+10);
            AnnualStrandedAssetByCompany26_globalpricing = zeros(length(CompanyNames),mean_Life+10);
            
            AnnualStrandedAssetByCompany19_regionalpricing = zeros(length(CompanyNames),mean_Life+10);
            AnnualStrandedAssetByCompany26_regionalpricing = zeros(length(CompanyNames),mean_Life+10);
            NumberofPlantsperCompanyperYear = zeros(length(CompanyNames),mean_Life+10);
            
            
            AnnualStrandedAssetByCountry19_globalpricing = zeros(length(CountryNames),mean_Life+10);
            AnnualStrandedAssetByCountry26_globalpricing = zeros(length(CountryNames),mean_Life+10);
            
            AnnualStrandedAssetByCountry19_regionalpricing = zeros(length(CountryNames),mean_Life+10);
            AnnualStrandedAssetByCountry26_regionalpricing = zeros(length(CountryNames),mean_Life+10);
        elseif FUEL == 2 
            AnnualEmissionsByCompany = zeros(length(CompanyNames),mean_Life+20);
            AnnualEmissionsByCountry = zeros(length(CountryNames),mean_Life+20);

            AnnualCapacityByCompany = zeros(length(CompanyNames),mean_Life+20);
            AnnualStrandedAssetByCompany19_globalpricing = zeros(length(CompanyNames),mean_Life+20);
            AnnualStrandedAssetByCompany26_globalpricing = zeros(length(CompanyNames),mean_Life+20);
            
            AnnualStrandedAssetByCompany19_regionalpricing = zeros(length(CompanyNames),mean_Life+20);
            AnnualStrandedAssetByCompany26_regionalpricing = zeros(length(CompanyNames),mean_Life+20);
            NumberofPlantsperCompanyperYear = zeros(length(CompanyNames),mean_Life+20);
            
            
            AnnualStrandedAssetByCountry19_globalpricing = zeros(length(CountryNames),mean_Life+20);
            AnnualStrandedAssetByCountry26_globalpricing = zeros(length(CountryNames),mean_Life+20);
            
            AnnualStrandedAssetByCountry19_regionalpricing = zeros(length(CountryNames),mean_Life+20);
            AnnualStrandedAssetByCountry26_regionalpricing = zeros(length(CountryNames),mean_Life+20);
        end
        
        for generator = 1:length(Plants)
            for Company = 1:length(CompanyNames)
                if LifeLeft(generator) > 0
                    if strcmpi(Plants_string{generator,1},CompanyNames{Company,1})
                        AnnualCapacityByCompany(Company,1:LifeLeft(generator)) = AnnualCapacityByCompany(Company,1:LifeLeft(generator)) + Plants(generator,1)*(Plants(generator,5)/100);
                        NumberofPlantsperCompanyperYear(Company,1:LifeLeft(generator)) = NumberofPlantsperCompanyperYear(Company,1:LifeLeft(generator))+1*(Plants(generator,5)/100);
                    end
                end
            end
        end
        
        for generator = 1:length(Plants)
            for Company = 1:length(CompanyNames)
                if LifeLeft(generator) > 0
                    if strcmpi(Plants_string{generator,1},CompanyNames{Company,1})
                        for yr = 1:nanmax(LifeLeft)
                            AnnualStrandedAssetByCompany19_globalpricing(Company,yr) = AnnualStrandedAssetByCompany19_globalpricing(Company,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,1),2));
                            AnnualStrandedAssetByCompany26_globalpricing(Company,yr) = AnnualStrandedAssetByCompany26_globalpricing(Company,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,3),2));

                            AnnualStrandedAssetByCompany19_regionalpricing(Company,yr) = AnnualStrandedAssetByCompany19_regionalpricing(Company,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,2),2));
                            AnnualStrandedAssetByCompany26_regionalpricing(Company,yr) = AnnualStrandedAssetByCompany26_regionalpricing(Company,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,4),2));
                        end
                    end
                end
            end
        end

        if gentype == 1
            for generator = 1:length(Plants)
                for Company = 1:length(CompanyNames)
                    if LifeLeft(generator) > 0
                        if strcmpi(Plants_string{generator,1},CompanyNames{Company,1})
                            AnnualCapacityByCompany(Company,1:LifeLeft(generator)) = AnnualCapacityByCompany(Company,1:LifeLeft(generator)) + Plants(generator,1)*(Plants(generator,5)/100);
                            AnnualEmissionsByCompany(Company,1:LifeLeft(generator)) = AnnualEmissionsByCompany(Company,1:LifeLeft(generator)) + (Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                            AnnualEmissionsByCompany_Coal_strings{Company,1} = CompanyNames{Company,1};
                        end
                    end
                end
            end
                            
            CoalAnnualEmissions_Fuel = nansum(AnnualEmissionsByCompany,1);
            CommittedEmissions = nansum(AnnualEmissionsByCompany,2);
            CoalAnnualEmissions = zeros(length(CommittedEmissions),50);

            for Company = 1:length(CommittedEmissions)
                for yr = 1:nanmax(LifeLeft)
                    CoalAnnualEmissions(Company,yr) = CoalAnnualEmissions(Company,yr) + squeeze(nansum(AnnualEmissionsByCompany(Company,yr:end)));
                end
            end

            CoalAnnualEmissions = nansum(CoalAnnualEmissions,1);
            
            CoalAnnualEmissions_Company = AnnualEmissionsByCompany;

            for generator = 1:length(Plants)
                for Country = 1:length(CountryNames)
                    if LifeLeft(generator) > 0
                        if strcmpi(Plants_string{generator,2},CountryNames{Country,1})
                            AnnualEmissionsByCountry(Country,1:LifeLeft(generator)) = AnnualEmissionsByCountry(Country,1:LifeLeft(generator)) + (Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Heat_rate(generator))*(Emission_factor(generator)*TJ_to_BTu*Kg_CO2_to_t_C02)) * (Plants(generator,5)/100); 
                            AnnualEmissionsByCountry_Coal_strings{Country,1} = CountryNames{Country,1};
                        end
                    end
                end
            end
            
            for generator = 1:length(Plants)
                for Country = 1:length(CountryNames)
                    if LifeLeft(generator) > 0
                        if strcmpi(Plants_string{generator,2},CountryNames{Country,1})     
                            for yr = 1:mean_Life
                                AnnualStrandedAssetByCountry19_globalpricing(Country,yr) = AnnualStrandedAssetByCountry19_globalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,1),2));
                                AnnualStrandedAssetByCountry26_globalpricing(Country,yr) = AnnualStrandedAssetByCountry26_globalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,3),2));

                                AnnualStrandedAssetByCountry19_regionalpricing(Country,yr) = AnnualStrandedAssetByCountry19_regionalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,2),2));
                                AnnualStrandedAssetByCountry26_regionalpricing(Country,yr) = AnnualStrandedAssetByCountry26_regionalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,4),2));
                            end
                        end
                    end
                end
            end
        
            
            CoalAnnualEmissions_Country = AnnualEmissionsByCountry;
            
            AnnualStrandedAssetByCompany19_globalpricing_Coal = AnnualStrandedAssetByCompany19_globalpricing;
            AnnualStrandedAssetByCompany26_globalpricing_Coal = AnnualStrandedAssetByCompany26_globalpricing;
            AnnualStrandedAssetByCompany19_regionalpricing_Coal = AnnualStrandedAssetByCompany19_regionalpricing;
            AnnualStrandedAssetByCompany26_regionalpricing_Coal = AnnualStrandedAssetByCompany26_regionalpricing;
            
            AnnualStrandedAssetByCountry19_globalpricing_Coal = AnnualStrandedAssetByCountry19_globalpricing;
            AnnualStrandedAssetByCountry26_globalpricing_Coal = AnnualStrandedAssetByCountry26_globalpricing;
            AnnualStrandedAssetByCountry19_regionalpricing_Coal = AnnualStrandedAssetByCountry19_regionalpricing;
            AnnualStrandedAssetByCountry26_regionalpricing_Coal = AnnualStrandedAssetByCountry26_regionalpricing;
            
            
            figure()
            plot(1:mean_Life,nansum(AnnualStrandedAssetByCompany19_globalpricing(:,1:mean_Life),1))

            figure()
            plot(1:mean_Life,CoalAnnualEmissions_Fuel(:,1:mean_Life))
            ylabel('annual emissions')
            AnnualEmissionsByCompany_Coal_strings{end+1} = [];

            figure()
            plot(1:mean_Life,CoalAnnualEmissions(:,1:mean_Life))
            ylabel('committed emissions')

            save('../Data/Results/CoalAnnualEmissions.mat','CoalAnnualEmissions_Fuel','CoalAnnualEmissions_Country','CoalAnnualEmissions_Company','AnnualEmissionsByCompany_Coal_strings','AnnualEmissionsByCountry_Coal_strings','CommittedEmissions');
            save('../Data/Results/CoalCompanyCapacity.mat','AnnualCapacityByCompany','NumberofPlantsperCompanyperYear');
            save('../Data/Results/CoalStrandedAssets.mat','AnnualStrandedAssetByCompany19_globalpricing_Coal','AnnualStrandedAssetByCompany26_globalpricing_Coal',...
                'AnnualStrandedAssetByCompany19_regionalpricing_Coal','AnnualStrandedAssetByCompany26_regionalpricing_Coal',...
                'AnnualStrandedAssetByCountry19_globalpricing_Coal','AnnualStrandedAssetByCountry26_globalpricing_Coal',...
                'AnnualStrandedAssetByCountry19_regionalpricing_Coal','AnnualStrandedAssetByCountry26_regionalpricing_Coal');
        else
            for generator = 1:length(Plants)
                for Company = 1:length(CompanyNames)
                    if LifeLeft(generator) > 0
                        if strcmpi(Plants_string{generator,1},CompanyNames{Company,1})
                            AnnualCapacityByCompany(Company,1:LifeLeft(generator)) = AnnualCapacityByCompany(Company,1:LifeLeft(generator)) + Plants(generator,1)*(Plants(generator,5)/100);
                            AnnualEmissionsByCompany(Company,1:LifeLeft(generator)) = AnnualEmissionsByCompany(Company,1:LifeLeft(generator)) + Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator))* (Plants(generator,5)/100); %
                            AnnualEmissionsByCompany_Gas_strings{Company,1} = CompanyNames{Company,1};
                        end
                    end
                end
            end

                            
            GasAnnualEmissions_Fuel = nansum(AnnualEmissionsByCompany,1);
            CommittedEmissions = nansum(AnnualEmissionsByCompany,2);
            GasAnnualEmissions = zeros(length(CommittedEmissions),50);

            for Company = 1:length(CommittedEmissions)
                for yr = 1:nanmax(LifeLeft)
                    GasAnnualEmissions(Company,yr) = GasAnnualEmissions(Company,yr) + squeeze(nansum(AnnualEmissionsByCompany(Company,yr:end)));
                end
            end

            GasAnnualEmissions = nansum(GasAnnualEmissions,1);
               
            GasAnnualEmissions = nansum(AnnualEmissionsByCompany,1);
            GasAnnualEmissions_Company = AnnualEmissionsByCompany;

            for generator = 1:length(Plants)
                for Country = 1:length(CountryNames)
                    if LifeLeft(generator) > 0
                        if strcmpi(Plants_string{generator,2},CountryNames{Country,1})
                            AnnualEmissionsByCountry(Country,1:LifeLeft(generator)) = AnnualEmissionsByCountry(Country,1:LifeLeft(generator)) + Plants(generator,1).*Plants(generator,3).*AnnualHours.*(Emission_factor(generator))* (Plants(generator,5)/100); 
                            AnnualEmissionsByCountry_Gas_strings{Country,1} = CountryNames{Country,1};
                        end
                    end
                end
            end
            
            for generator = 1:length(Plants)
                for Country = 1:length(CountryNames)
                    if LifeLeft(generator) > 0
                        if strcmpi(Plants_string{generator,2},CountryNames{Country,1})     
                            for yr = 1:mean_Life
                                AnnualStrandedAssetByCountry19_globalpricing(Country,yr) = AnnualStrandedAssetByCountry19_globalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,1),2));
                                AnnualStrandedAssetByCountry26_globalpricing(Country,yr) = AnnualStrandedAssetByCountry26_globalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,3),2));

                                AnnualStrandedAssetByCountry19_regionalpricing(Country,yr) = AnnualStrandedAssetByCountry19_regionalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,2),2));
                                AnnualStrandedAssetByCountry26_regionalpricing(Country,yr) = AnnualStrandedAssetByCountry26_regionalpricing(Country,yr) + squeeze(nansum(AnnualStrandedAssets(generator,yr:end,4),2));
                            end
                        end
                    end
                end
            end

            GasAnnualEmissions_Fuel = nansum(AnnualEmissionsByCountry,1);
            GasAnnualEmissions_Country = AnnualEmissionsByCountry;
            
            AnnualStrandedAssetByCompany19_globalpricing_Gas = AnnualStrandedAssetByCompany19_globalpricing;
            AnnualStrandedAssetByCompany26_globalpricing_Gas = AnnualStrandedAssetByCompany26_globalpricing;
            AnnualStrandedAssetByCompany19_regionalpricing_Gas = AnnualStrandedAssetByCompany19_regionalpricing;
            AnnualStrandedAssetByCompany26_regionalpricing_Gas = AnnualStrandedAssetByCompany26_regionalpricing;
            
            AnnualStrandedAssetByCountry19_globalpricing_Gas = AnnualStrandedAssetByCountry19_globalpricing;
            AnnualStrandedAssetByCountry26_globalpricing_Gas = AnnualStrandedAssetByCountry26_globalpricing;
            AnnualStrandedAssetByCountry19_regionalpricing_Gas = AnnualStrandedAssetByCountry19_regionalpricing;
            AnnualStrandedAssetByCountry26_regionalpricing_Gas = AnnualStrandedAssetByCountry26_regionalpricing;
            
            
            figure()
            plot(1:mean_Life,nansum(AnnualStrandedAssetByCompany19_globalpricing(:,1:mean_Life),1))

            figure()
            plot(1:mean_Life,GasAnnualEmissions_Fuel(:,1:mean_Life))
            ylabel('annual emissions')
            AnnualEmissionsByCompany_Gas_strings{end+1} = [];

            figure()
            plot(1:mean_Life,GasAnnualEmissions(:,1:mean_Life))
            ylabel('committed emissions')

            save('../Data/Results/GasAnnualEmissions.mat','GasAnnualEmissions_Fuel','GasAnnualEmissions_Country','GasAnnualEmissions_Company','AnnualEmissionsByCompany_Gas_strings','AnnualEmissionsByCountry_Gas_strings','CommittedEmissions');
            save('../Data/Results/GasCompanyCapacity.mat','AnnualCapacityByCompany','NumberofPlantsperCompanyperYear');
            save('../Data/Results/GasStrandedAssets.mat','AnnualStrandedAssetByCompany19_globalpricing_Gas','AnnualStrandedAssetByCompany26_globalpricing_Gas',...
                'AnnualStrandedAssetByCompany19_regionalpricing_Gas','AnnualStrandedAssetByCompany26_regionalpricing_Gas',...
                'AnnualStrandedAssetByCountry19_globalpricing_Gas','AnnualStrandedAssetByCountry26_globalpricing_Gas',...
                'AnnualStrandedAssetByCountry19_regionalpricing_Gas','AnnualStrandedAssetByCountry26_regionalpricing_Gas');
        end
   
    elseif CombineFuelTypeResults == 1
        load('../Data/Results/CoalAnnualEmissions.mat');
        load ../Data/Results/PowerPlantFinances_byCompany_Coal.mat
        load ../Data/Results/PowerPlantFinances_byCountry_Coal.mat
        load ../Data/Results/CoalStrandedAssets.mat
        
        
        PowerPlantFinances_byCompany_Coal = PowerPlantFinances_byCompany;
        PowerPlantFinances_byCountry_Coal = PowerPlantFinances_byCountry;
        PowerPlantFinances_byCompany_Coal(PowerPlantFinances_byCompany_Coal<0) = 0;
        PowerPlantFinances_byCountry_Coal(PowerPlantFinances_byCountry_Coal<0) = 0;
        
        load('../Data/Results/GasAnnualEmissions.mat');
        load ../Data/Results/PowerPlantFinances_byCompany_Gas.mat
        load ../Data/Results/PowerPlantFinances_byCountry_Gas.mat
        load ../Data/Results/GasStrandedAssets.mat
        
        PowerPlantFinances_byCompany_Gas = PowerPlantFinances_byCompany;
        PowerPlantFinances_byCountry_Gas = PowerPlantFinances_byCountry;
        PowerPlantFinances_byCompany_Gas(PowerPlantFinances_byCompany_Gas<0) = 0;
        PowerPlantFinances_byCountry_Gas(PowerPlantFinances_byCountry_Gas<0) = 0;
        
        AnnualEmissions = [CoalAnnualEmissions_Fuel' GasAnnualEmissions_Fuel'];
        NewColormap = autumn(length(1:3));
        
        AnnualEmissions = AnnualEmissions./(1e9);%converts from tons to gigatons 
        
        figure()
        area(CarbonTaxYear(1:length(AnnualEmissions)),AnnualEmissions)
        colororder(NewColormap);
        legend({'Coal','Natural Gas'})
        xlim([current_year 2059])
        xlabel('Year')
        ylabel('Annual Emissions (GtCO2)')
        aY = gca;
        exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualEmissions_byFuel.eps','ContentType','vector');    
        
        CountrySA = [squeeze(PowerPlantFinances_byCountry_Coal(:,1,5)); squeeze(PowerPlantFinances_byCountry_Gas(:,1,5))];
        CountrySA(isnan(CountrySA)) = 0;

        Country_Names = [AnnualEmissionsByCountry_Coal_strings; AnnualEmissionsByCountry_Gas_strings];
        Country_Names = unique(Country_Names);

        CountryEmissions = zeros(length(Country_Names),50);

        for Country = 1:length(Country_Names)
            for Country_emissions = 1:length(AnnualEmissionsByCountry_Coal_strings)
                if strcmpi(AnnualEmissionsByCountry_Coal_strings{Country_emissions,1},Country_Names{Country,1})
                    CountryEmissions(Country,1:50) = CountryEmissions(Country,1:50) + CoalAnnualEmissions_Country(Country_emissions,1:50);
                end
            end
        end

        for Country = 1:length(Country_Names)
            for Country_emissions = 1:length(AnnualEmissionsByCountry_Gas_strings)
                if strcmpi(AnnualEmissionsByCountry_Gas_strings{Country_emissions,1},Country_Names{Country,1})
                    CountryEmissions(Country,1:50) = CountryEmissions(Country,1:50) + GasAnnualEmissions_Country(Country_emissions,1:50);
                end
            end
        end


        CountryEmissions_strings = cat(1,AnnualEmissionsByCountry_Coal_strings,AnnualEmissionsByCountry_Gas_strings);
        Newcolorbar = autumn(length(1:7));
        COLORS = zeros(length(CountryEmissions),3);
        [Top_Countries_Emissions indx_country] =maxk(CountryEmissions,10);
        
        Top_Countries_strings = Country_Names(indx_country(:,1),1);
        RestofCountriesEmissions = nansum(CountryEmissions,1)-nansum(Top_Countries_Emissions,1);
        CountryEmissions = [RestofCountriesEmissions' Top_Countries_Emissions']';
        
        CountryStrings2 = cell(length(Top_Countries_strings)+1,1);
        CountryStrings2(2:end,1) = Top_Countries_strings;
        CountryStrings2{1,1} = 'Rest of world';
        
        Top_Countries_strings = CountryStrings2;

        CountryEmissions = CountryEmissions./(1e9);%converts from tons to gigatons 
        
        
        figure()
        area(CarbonTaxYear(1:length(CountryEmissions)),CountryEmissions')
        legend(Top_Countries_strings)
        xlim([current_year 2059])
        xlabel('Year')
        ylabel('Annual Emissions (GtCO2)')
        aY = gca;
        exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualEmissions_byCountry.eps','ContentType','vector');              
        Companies = [AnnualEmissionsByCompany_Coal_strings(1:end-1); AnnualEmissionsByCompany_Gas_strings(1:end-1)];
        Companies = unique(Companies);

        StrandedAssetsbyCompany = zeros(length(Companies),47);
        CompanyEmissions= zeros(length(Companies),47);

        for Company = 1:length(Companies)
            for Coal_Emissions = 1:length(AnnualEmissionsByCompany_Coal_strings)
                if strcmpi(AnnualEmissionsByCompany_Coal_strings{Coal_Emissions,1},Companies{Company,1})
                    StrandedAssetsbyCompany(Company,1:47) = StrandedAssetsbyCompany(Company,1:47) + PowerPlantFinances_byCompany_Coal(Coal_Emissions,1:47,5);
                    CompanyEmissions(Company,1:47) = CompanyEmissions(Company,1:47) + CoalAnnualEmissions_Company(Coal_Emissions,1:47);
                end
            end
        end

        for Company = 1:length(Companies)
            for Gas_Emissions = 1:length(AnnualEmissionsByCompany_Gas_strings)
                if strcmpi(AnnualEmissionsByCompany_Gas_strings{Gas_Emissions,1},Companies{Company,1})
                    StrandedAssetsbyCompany(Company,1:46) = StrandedAssetsbyCompany(Company,1:46) + PowerPlantFinances_byCompany_Gas(Gas_Emissions,1:46,5);
                    CompanyEmissions(Company,1:47) = CompanyEmissions(Company,1:47) + GasAnnualEmissions_Company(Gas_Emissions,1:47);
                end
            end
        end
        
        
        CompanyEmissions_strings = cat(1,AnnualEmissionsByCompany_Coal_strings(1:end-1),AnnualEmissionsByCompany_Gas_strings(1:end-1));
        CompanyStrings = Companies;
        
        CompanyEmissionsUnique = CompanyEmissions;
        CompanySA_Unique = zeros(length(CompanyStrings),1);
        
        Newcolorbar = autumn(length(CompanyEmissionsUnique));
        ColorMatrix = zeros(length(CompanyEmissionsUnique),2);           

        CompanySA_Unique(isnan(CompanySA_Unique)) = 0;
        ColorMatrix(:,1) = 1:length(CompanyEmissionsUnique);
        ColorMatrix(:,2) = CompanySA_Unique;
        ColorMatrix(ColorMatrix == 0) = nan;
        ColorMatrix = sort(ColorMatrix,2);
        ColorMatrix(isnan(ColorMatrix)) = 0;
        
        [NextNinety_Emissions indx] =maxk(CompanyEmissionsUnique,100);%extracts the top 100 companies
        [NextNinety_Emissions indx] =mink(NextNinety_Emissions,90);%subtracts the top 10
        [TopTen_Emissions indx] =maxk(CompanyEmissionsUnique,10);
        TopColors = Newcolorbar(ColorMatrix(indx(:,1),1),:);
        COLORS = [TopColors; Newcolorbar(1,:,:)];
        
        RestStrandedEmissions = nansum(CompanyEmissionsUnique,1);
        NextNinety_Emissions = nansum(NextNinety_Emissions,1);
        TopTen_Emissions = nansum(TopTen_Emissions,1);
        RestStrandedEmissions = RestStrandedEmissions - NextNinety_Emissions - TopTen_Emissions;
        StrandedEmissions = [RestStrandedEmissions' NextNinety_Emissions' TopTen_Emissions'];
        
        StrandedEmissions = StrandedEmissions./(1e9);%converts from tons to gigatons 
        
        figure()
        area(CarbonTaxYear(1:length(StrandedEmissions)),StrandedEmissions)
        legend('Rest','Next 90','Top 10')
        xlim([current_year 2059])
        % ylim([0 12])
        xlabel('Year')
        ylabel('Annual Emissions (GtCO2)')
        aY = gca;
        exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualEmissions_byCompany.eps','ContentType','vector');   
        
        
        TotalStrandedAssets_Global_19_ByFuel = [nansum(AnnualStrandedAssetByCompany19_globalpricing_Coal,1); nansum(AnnualStrandedAssetByCompany19_globalpricing_Gas,1)];
        TotalStrandedAssets_Global_26_ByFuel  = [nansum(AnnualStrandedAssetByCompany26_globalpricing_Coal,1); nansum(AnnualStrandedAssetByCompany26_globalpricing_Gas,1)];
        
        TotalStrandedAssets_Regional_19_ByFuel = [nansum(AnnualStrandedAssetByCompany19_regionalpricing_Coal,1); nansum(AnnualStrandedAssetByCompany19_regionalpricing_Gas,1)];
        TotalStrandedAssets_Regional_26_ByFuel = [nansum(AnnualStrandedAssetByCompany26_regionalpricing_Coal,1); nansum(AnnualStrandedAssetByCompany26_regionalpricing_Gas,1)];
        
        
        figure()
        bar(1,TotalStrandedAssets_Regional_19_ByFuel(:,1)/(1e12),'stacked')
        hold on
        bar(2,TotalStrandedAssets_Regional_26_ByFuel(:,1)/(1e12),'stacked')
        legend({'Coal','Natural Gas'})
        ylim([0 25])
        % xlabel('Year')
        ylabel('Stranded Assets (USD $)')
        aY = gca;
        exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualStrandings_byFuel_bar.eps','ContentType','vector');  

        TotalStrandedAssets_Global_19_ByFuel =  TotalStrandedAssets_Global_19_ByFuel(:,1);
        TotalStrandedAssets_Global_26_ByFuel =  TotalStrandedAssets_Global_26_ByFuel(:,1);
        
        TotalStrandedAssets_Country_Global_19 = [AnnualStrandedAssetByCountry19_globalpricing_Coal; AnnualStrandedAssetByCountry19_globalpricing_Gas];
        TotalStrandedAssets_Country_Global_26 = [AnnualStrandedAssetByCountry26_globalpricing_Coal; AnnualStrandedAssetByCountry26_globalpricing_Gas];
        
        TotalStrandedAssets_Country_Regional_26 = [AnnualStrandedAssetByCountry26_regionalpricing_Coal; AnnualStrandedAssetByCountry26_regionalpricing_Gas];
        TotalStrandedAssets_Country_Regional_19 = [AnnualStrandedAssetByCountry19_regionalpricing_Coal; AnnualStrandedAssetByCountry19_regionalpricing_Gas];
        CountryStrings = Country_Names;
        
        CountryassetsUnique19_global = zeros(length(CountryStrings),50);
        CountryassetsUnique26_global = zeros(length(CountryStrings),50);
        
        CountryassetsUnique19_regional = zeros(length(CountryStrings),50);
        CountryassetsUnique26_regional = zeros(length(CountryStrings),50);
        
        for  i = 1:length(CountryStrings)
            for j = 1:length(CountryEmissions_strings)
                if strcmpi(CountryEmissions_strings{j,1},CountryStrings{i,1})
                   CountryassetsUnique19_global(i,:) = CountryassetsUnique19_global(i,:) + TotalStrandedAssets_Country_Global_19(j,:);
                   CountryassetsUnique26_global(i,:) = CountryassetsUnique26_global(i,:) + TotalStrandedAssets_Country_Global_26(j,:);
                   
                   CountryassetsUnique19_regional(i,:) = CountryassetsUnique19_regional(i,:) + TotalStrandedAssets_Country_Regional_19(j,:);
                   CountryassetsUnique26_regional(i,:) = CountryassetsUnique26_regional(i,:) + TotalStrandedAssets_Country_Regional_26(j,:);
                end
            end
        end
        
        [~, indx] = maxk(CountryassetsUnique19_regional(:,1),5);%extracts the top 10
        Top_Countries_assets_regional19 = CountryassetsUnique19_regional(indx,:);
        RestofCountriesEmissions_regional19 = nansum(CountryassetsUnique19_regional,1)-nansum(Top_Countries_assets_regional19,1);
        CountryAssets_regional19 = [RestofCountriesEmissions_regional19' Top_Countries_assets_regional19']';
        Top_Countries_strings = cell(6,1);
        Top_Countries_strings(1,1) = {'REST OF WORLD'};
        Top_Countries_strings(2:end,1) = CountryStrings(indx(:,1),1);
        


        CountryNames = {'Albania', 'Australia', 'Austria', 'Belgium', 'Bosnia-Herzegovina', 'Bulgaria', 'Canada',...
                        'Croatia', 'Cyprus', 'Czech Republic', 'Denmark', 'Estonia', 'Finland', 'France', 'Germany', 'Greece', 'Guam', 'Hungary',...
                        'Iceland', 'Ireland', 'Italy', 'Latvia', 'Lithuania', 'Luxembourg', 'Malta', 'Montenegro', 'Netherlands', 'New Zealand',...
                        'Norway', 'Poland', 'Portugal', 'Puerto Rico', 'Romania', 'Serbia', 'Slovakia', 'Slovenia', 'Spain', 'Sweden', 'Switzerland', ...
                        'North Macedonia', 'Türkiye', 'United Kingdom', 'United States','ENGLAND & WALES','Scotland','Ireland','Moldova','Ukraine','Russia'};
        
        Europe_Assets = 0;
        for Nation = 1:length(CountryStrings)
            for National_name = 1:length(CountryNames)
                if strcmp(CountryStrings{Nation}, CountryNames{National_name})
                   Europe_Assets = Europe_Assets + CountryassetsUnique19_regional(Nation,1);
                end
            end
        end

        US_Assets = CountryassetsUnique19_regional(165,1);

        figure()
        bar(1,CountryAssets_regional19(:,1)/(1e12),'stacked')
        % colororder(NewColormap);
        legend(Top_Countries_strings)
        ylim([0 25])
        % xlabel('Year')
        ylabel('Stranded Assets (USD $)')
        aY = gca;
        exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualStrandings_byCountry_1_9_bar.eps','ContentType','vector');
        CountryAssets_regional19 = CountryAssets_regional19(:,1);
        

        figure()
        area(CarbonTaxYear(1:length(CountryAssets_regional19)),CountryAssets_regional19'/(1e12))
        legend(Top_Countries_strings)
        xlim([current_year 2059])
        % ylim([0 14e12])
        xlabel('Year')
        ylabel('Stranded Assets (USD $)')
        aY = gca;
        % exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualAssets_byCountry_global19.eps','ContentType','vector');  
        
        [~, indx] = maxk(nansum(CountryassetsUnique26_regional,2),5);%extracts the top 10
        Top_Countries_assets_regional26 = CountryassetsUnique26_regional(indx,:);
        RestofCountriesEmissions_regional26 = nansum(TotalStrandedAssets_Country_Regional_26,1)-nansum(Top_Countries_assets_regional26,1);
        CountryAssets_regional26 = [RestofCountriesEmissions_regional26' Top_Countries_assets_regional26']';
        Top_Countries_strings = cell(6,1);
        Top_Countries_strings(1,1) = {'REST OF WORLD'};
        Top_Countries_strings(2:end,1) = CountryStrings(indx(:,1),1);
        

        figure()
        bar(1,CountryAssets_regional26(:,1)/(1e12),'stacked')
        legend(Top_Countries_strings)
        ylim([0 25])
        ylabel('Stranded Assets (USD $)')
        aY = gca;
        exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualStrandings_byCountry_2_6_bar.eps','ContentType','vector');
        CountryAssets_regional26 = CountryAssets_regional26(:,1);

        [~, indx] = maxk(nansum(CountryassetsUnique19_regional,2),5);%extracts the top 10
        Top_Countries_assets_regional19 = CountryassetsUnique19_regional(indx,:);
        RestofCountriesEmissions_regional19 = nansum(TotalStrandedAssets_Country_Regional_19,1)-nansum(Top_Countries_assets_regional19,1);
        CountryAssets_regional19 = [RestofCountriesEmissions_regional19' Top_Countries_assets_regional19']';
        Top_Countries_strings = cell(6,1);
        Top_Countries_strings(1,1) = {'REST OF WORLD'};
        Top_Countries_strings(2:end,1) = CountryStrings(indx(:,1),1);

        figure()
        area(CarbonTaxYear(1:length(CountryAssets_regional19)),CountryAssets_regional19'/(1e12))
        legend(Top_Countries_strings)
        xlim([current_year 2059])
        xlabel('Year')
        ylabel('Stranded Assets (USD $)')
        aY = gca;

        [~, indx] = maxk(nansum(CountryassetsUnique26_regional,2),5);%extracts the top 10
        Top_Countries_assets_regional26 = CountryassetsUnique26_regional(indx,:);
        RestofCountriesEmissions_regional26 = nansum(TotalStrandedAssets_Country_Regional_26,1)-nansum(Top_Countries_assets_regional26,1);
        CountryAssets_regional26 = [RestofCountriesEmissions_regional26' Top_Countries_assets_regional26']';
        Top_Countries_strings = cell(6,1);
        Top_Countries_strings(1,1) = {'REST OF WORLD'};
        Top_Countries_strings(2:end,1) = CountryStrings(indx(:,1),1);

        figure()
        area(CarbonTaxYear(1:length(CountryAssets_regional26)),CountryAssets_regional26'/(1e12))
        legend(Top_Countries_strings)
        xlim([current_year 2059])
        % ylim([0 7e12])
        xlabel('Year')
        ylabel('Stranded Assets (USD $)')
        aY = gca;

        TotalStrandedAssets_Company_Global_19 = [AnnualStrandedAssetByCompany19_globalpricing_Coal; AnnualStrandedAssetByCompany19_globalpricing_Gas];
        TotalStrandedAssets_Company_Global_26 = [AnnualStrandedAssetByCompany26_globalpricing_Coal; AnnualStrandedAssetByCompany26_globalpricing_Gas];
        
        TotalStrandedAssets_Company_Regional_26 = [AnnualStrandedAssetByCompany26_regionalpricing_Coal; AnnualStrandedAssetByCompany26_regionalpricing_Gas];
        TotalStrandedAssets_Company_Regional_19 = [AnnualStrandedAssetByCompany19_regionalpricing_Coal; AnnualStrandedAssetByCompany19_regionalpricing_Gas];
        
         CompanyAssetsUnique_global19 = zeros(length(CompanyStrings),50); CompanyAssetsUnique_global26 = zeros(length(CompanyStrings),50);
         CompanyAssetsUnique_regional19 = zeros(length(CompanyStrings),50); CompanyAssetsUnique_regional26 = zeros(length(CompanyStrings),50);
         
        
        for  i = 1:length(CompanyStrings)
            for j = 1:length(CompanyEmissions_strings)
                if strcmpi(CompanyEmissions_strings{j,1},CompanyStrings{i,1})
                   CompanyAssetsUnique_global19(i,:) = CompanyAssetsUnique_global19(i,:) + TotalStrandedAssets_Company_Global_19(j,:);
                   CompanyAssetsUnique_global26(i,:) = CompanyAssetsUnique_global26(i,:) + TotalStrandedAssets_Company_Global_26(j,:);
                   CompanyAssetsUnique_regional19(i,:) = CompanyAssetsUnique_regional19(i,:) + TotalStrandedAssets_Company_Regional_19(j,:);
                   CompanyAssetsUnique_regional26(i,:) = CompanyAssetsUnique_regional26(i,:) + TotalStrandedAssets_Company_Regional_26(j,:);
                end
            end
        end

        save('../Data/Results/CompanyAssetsUnique_regional19','CompanyAssetsUnique_regional19','CompanyEmissions_strings','CompanyStrings','AnnualStrandedAssetByCompany19_regionalpricing_Coal','AnnualStrandedAssetByCompany19_regionalpricing_Gas')
        NextNinety_Assets = maxk(CompanyAssetsUnique_regional19,100);%extracts the top 100 companies
        NextNinety_Assets = mink(NextNinety_Assets,90);%subtracts the top 10
        TopTen_Assets = maxk(CompanyAssetsUnique_regional19,10);
        
        RestStrandedAssets = nansum(CompanyAssetsUnique_regional19,1);
        NextNinety_Assets = nansum(NextNinety_Assets,1);
        TopTen_Assets = nansum(TopTen_Assets,1);
        RestStrandedAssets = RestStrandedAssets - NextNinety_Assets - TopTen_Assets;
        StrandedAssets = [RestStrandedAssets' NextNinety_Assets' TopTen_Assets'];
        
        figure()
        bar(1,StrandedAssets(1,:)/(1e12),'stacked')
        legend('Rest','Next 90','Top 10')
        ylim([0 25])
        ylabel('Stranded Assets (USD $)')
        aY = gca;
        exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualStrandings_byCompany_1_9_bar.eps','ContentType','vector');

        StrandedAssetsbycompany19 = StrandedAssets(1,:);

        figure()
        area(CarbonTaxYear(1:length(StrandedAssets)),StrandedAssets/(1e12))
        legend('Rest','Next 90','Top 10')
        % colororder(COLORS);
        xlim([current_year 2059])
        % ylim([0 14e12])
        xlabel('Year')
        ylabel('Stranded Assets ($-USD)')
        aY = gca;
        
        NextNinety_Assets = maxk(CompanyAssetsUnique_regional26,100);%extracts the top 100 companies
        NextNinety_Assets = mink(NextNinety_Assets,90);%subtracts the top 10
        TopTen_Assets = maxk(CompanyAssetsUnique_regional26,10);
        
        RestStrandedAssets = nansum(CompanyAssetsUnique_regional26,1);
        NextNinety_Assets = nansum(NextNinety_Assets,1);
        TopTen_Assets = nansum(TopTen_Assets,1);
        RestStrandedAssets = RestStrandedAssets - NextNinety_Assets - TopTen_Assets;
        StrandedAssets = [RestStrandedAssets' NextNinety_Assets' TopTen_Assets'];
        
        figure()
        bar(1,StrandedAssets(1,:)/(1e12),'stacked')
        legend('Rest','Next 90','Top 10')
        ylim([0 25])
        ylabel('Stranded Assets (USD $)')
        aY = gca;
        exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualStrandings_byCompany_2_6_bar.eps','ContentType','vector');

        StrandedAssetsbycompany26 = StrandedAssets(1,:);
        save('../Data/Results/figure_4_stats.mat','TotalStrandedAssets_Global_19_ByFuel','TotalStrandedAssets_Global_26_ByFuel','CountryAssets_regional19','CountryAssets_regional26','StrandedAssetsbycompany19','StrandedAssetsbycompany26')
        figure()
        area(CarbonTaxYear(1:length(StrandedAssets)),StrandedAssets/(1e12))
        legend('Rest','Next 90','Top 10')
        % colororder(COLORS);
        xlim([current_year 2059])
        % ylim([0 7e12])
        xlabel('Year')
        ylabel('Stranded Assets ($-USD)')
        aY = gca;
        
        NextNinety_Assets = maxk(CompanyAssetsUnique_regional19,100);%extracts the top 100 companies
        NextNinety_Assets = mink(NextNinety_Assets,90);%subtracts the top 10
        TopTen_Assets = maxk(CompanyAssetsUnique_regional19,10);

        RestStrandedAssets = nansum(CompanyAssetsUnique_regional19,1);
        NextNinety_Assets = nansum(NextNinety_Assets,1);
        TopTen_Assets = nansum(TopTen_Assets,1);
        RestStrandedAssets = RestStrandedAssets - NextNinety_Assets - TopTen_Assets;
        StrandedAssets = [RestStrandedAssets' NextNinety_Assets' TopTen_Assets'];

        figure()
        area(CarbonTaxYear(1:length(StrandedAssets)),StrandedAssets/(1e12))
        legend('Rest','Next 90','Top 10')
        % colororder(COLORS);
        xlim([current_year 2059])
        % ylim([0 14e12])
        xlabel('Year')
        ylabel('Stranded Assets ($-USD)')
        aY = gca;
        % exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualAssets_byCompany_regional19.eps','ContentType','vector');  

        NextNinety_Assets = maxk(CompanyAssetsUnique_regional26,100);%extracts the top 100 companies
        NextNinety_Assets = mink(NextNinety_Assets,90);%subtracts the top 10
        TopTen_Assets = maxk(CompanyAssetsUnique_regional26,10);

        RestStrandedAssets = nansum(CompanyAssetsUnique_regional26,1);
        NextNinety_Assets = nansum(NextNinety_Assets,1);
        TopTen_Assets = nansum(TopTen_Assets,1);
        RestStrandedAssets = RestStrandedAssets - NextNinety_Assets - TopTen_Assets;
        StrandedAssets = [RestStrandedAssets' NextNinety_Assets' TopTen_Assets'];
        StrandedAssets(StrandedAssets<0) = 0;

        figure()
        area(CarbonTaxYear(1:length(StrandedAssets)),StrandedAssets/(1e12))
        legend('Rest','Next 90','Top 10')
        % colororder(COLORS);
        xlim([current_year 2059])
        xlabel('Year')
        % ylim([0 7e12])
        ylabel('Stranded Assets ($-USD)')
        aY = gca;
        % exportgraphics(aY,'../Plots/Figure - Annual Stranded Assets/AnnualAssets_byCompany_regional26.eps','ContentType','vector');  

    end
end
